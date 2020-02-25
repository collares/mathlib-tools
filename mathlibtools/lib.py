from pathlib import Path
import logging
import tempfile
import shutil
import tarfile
import signal
import re
import os
import subprocess
from datetime import datetime
from typing import Iterable, Union, List
from tempfile import TemporaryDirectory

import requests
import toml
from git import Repo, InvalidGitRepositoryError # type: ignore

from mathlibtools.delayed_interrupt import DelayedInterrupt
from mathlibtools.auth_github import auth_github

log = logging.getLogger("Mathlib tools")
log.setLevel(logging.INFO)
if (log.hasHandlers()):
    log.handlers.clear()
log.addHandler(logging.StreamHandler())


class InvalidLeanProject(Exception):
    pass

class InvalidMathlibProject(Exception):
    """A mathlib project is a Lean project depending on mathlib"""
    pass

class LeanDownloadError(Exception):
    pass

class LeanDirtyRepo(Exception):
    pass

def nightly_url(rev: str) -> str:
    """From a git rev, try to find an asset name and url."""
    g = auth_github()
    repo = g.get_repo("leanprover-community/mathlib-nightly")
    tags = {tag.name: tag.commit.sha for tag in repo.get_tags()}
    try:
        release = next(r for r in repo.get_releases()
                           if r.tag_name.startswith('nightly-') and
                           tags[r.tag_name] == rev)
    except StopIteration:
        raise LeanDownloadError('Error: no nightly archive found')

    try:
        asset = next(x for x in release.get_assets()
                     if x.name.startswith('mathlib-olean-nightly-'))
    except StopIteration:
        raise LeanDownloadError("Error: Release " + release.tag_name + 
               " does not contains a olean archive (this shouldn't happen...)")
    return asset.browser_download_url


DOT_MATHLIB = Path.home()/'.mathlib'
AZURE_URL = 'https://oleanstorage.blob.core.windows.net/mathlib/'

DOT_MATHLIB.mkdir(parents=True, exist_ok=True)

def pack(root: Path, srcs: Iterable[Path], target: Path) -> None:
    """Creates, as target, a tar.bz2 archive containing all paths from src,
    relative to the folder root"""
    try:
        target.unlink()
    except FileNotFoundError:
        pass
    cur_dir = Path.cwd()
    with DelayedInterrupt([signal.SIGTERM, signal.SIGINT]):
        os.chdir(str(root))
        ar = tarfile.open(str(target), 'w|bz2')
        for src in srcs:
            ar.add(str(src.relative_to(root)))
        ar.close()
    os.chdir(str(cur_dir))

def unpack_archive(fname: Union[str, Path], tgt_dir: Union[str, Path]) -> None:
    """Unpack archive. This is needed for python < 3.7."""
    shutil.unpack_archive(str(fname), str(tgt_dir))


def download(url: str, target: Path) -> None:
    """Download from url into target"""
    log.info('Trying to download {} to {}'.format(url, target))
    try:
        req = requests.get(url)
    except ConnectionError:
        raise LeanDownloadError("Can't connect to "+url)
    if req.status_code == 200:
        with DelayedInterrupt([signal.SIGTERM, signal.SIGINT]):
            with target.open('wb') as tgt:
                tgt.write(req.content)
    else:
        raise LeanDownloadError('Failed to download ' + url +'\n'
                                'status code was ' + str(req.status_code))


def get_mathlib_archive(rev: str) -> Path:
    """Download a mathlib archive for revision rev into .mathlib

    Return the archive Path. Will raise LeanDownloadError if nothing works.
    """

    fname = rev + '.tar.gz'
    path = DOT_MATHLIB/fname
    log.info('Looking for local mathlib oleans')
    if path.exists():
        log.info('Found local mathlib oleans')
        return path
    log.info('Looking for Azure mathlib oleans')
    try:
        download(AZURE_URL+fname, path)
        log.info('Found Azure mathlib oleans')
        return path
    except LeanDownloadError:
        pass
    log.info('Looking for GitHub mathlib oleans')
    download(nightly_url(rev), path)
    log.info('Found GitHub mathlib oleans')
    return path


class LeanProject:
    def __init__(self, repo: Repo, is_dirty: bool, rev: str, directory: Path,
            pkg_config: dict, deps: dict) -> None:
        """A Lean project."""
        self.repo = repo
        self.is_dirty = is_dirty
        self.rev = rev
        self.directory = directory
        self.pkg_config = pkg_config
        self.deps = deps

    @classmethod
    def from_path(cls, path: Path) -> 'LeanProject':
        """Builds a LeanProject from a Path object"""
        try:
            repo = Repo(path, search_parent_directories=True)
        except InvalidGitRepositoryError:
            raise InvalidLeanProject('Invalid git repository') 
        if repo.bare:
            raise InvalidLeanProject('Git repository is not initialized')
        is_dirty = repo.is_dirty()
        try:
            rev = repo.commit().hexsha
        except ValueError:
            rev = ''
        directory = Path(repo.working_dir)
        try:
            config = toml.load(directory/'leanpkg.toml')
        except FileNotFoundError:
            raise InvalidLeanProject('Missing leanpkg.toml')

        return cls(repo, is_dirty, rev, directory,
                   config['package'], config['dependencies'])

    @property
    def name(self) -> str:
        return self.pkg_config['name']
    
    @property
    def lean_version(self) -> str:
        return self.pkg_config['lean_version']

    @lean_version.setter
    def lean_version(self, value: str) -> None:
        self.pkg_config['lean_version'] = value


    @property
    def is_mathlib(self):
        return self.name == 'mathlib'

    @property
    def mathlib_rev(self) -> str:
        if self.is_mathlib:
            return self.rev
        if 'mathlib' not in self.deps:
            raise InvalidMathlibProject('This project does not depend on mathlib')
        try:
            rev = self.deps['mathlib']['rev']
        except KeyError:
            raise InvalidMathlibProject(
                'Project seems to refer to a local copy of mathlib '
                'instead of a GitHub repository')
        return rev

    @property
    def mathlib_folder(self) -> Path:
        if self.is_mathlib:
            return self.directory
        else:
            return self.directory/'_target'/'deps'/'mathlib'

    def read_config(self) -> None:
        try:
            config = toml.load(self.directory/'leanpkg.toml')
        except FileNotFoundError:
            raise InvalidLeanProject('Missing leanpkg.toml')

        self.deps = config['dependencies']
        self.pkg_config = config['package']

    def write_config(self) -> None:
        """Write leanpkg.toml for this project."""
        # Note we can't blindly use toml.dump because we need dict as values
        # for dependencies.
        with (self.directory/'leanpkg.toml').open('w') as cfg:
            cfg.write('[package]\n')
            cfg.write(toml.dumps(self.pkg_config))
            cfg.write('\n[dependencies]\n')
            for dep, val in self.deps.items():
                nval = str(val).replace(':', '=')
                cfg.write('{} = {}\n'.format(dep, nval))

    def get_mathlib_olean(self) -> None:
        """Get precompiled mathlib oleans for this project."""
        self.mathlib_folder.mkdir(parents=True, exist_ok=True)
        unpack_archive(get_mathlib_archive(self.mathlib_rev), 
                       self.mathlib_folder)
        # Let's now touch oleans, just in case
        now = datetime.now().timestamp()
        for p in (self.mathlib_folder/'src').glob('**/*.olean'):
            os.utime(str(p), (now, now))

    def mk_cache(self, force: bool = False) -> None:
        """Cache oleans for this project."""
        if self.is_dirty and not force:
            raise LeanDirtyRepo
        if not self.rev:
            raise ValueError('This project has no git commit.')
        tgt_folder = DOT_MATHLIB if self.is_mathlib else self.directory/'_cache'
        tgt_folder.mkdir(exist_ok=True)
        archive = tgt_folder/(str(self.rev) + '.tar.bz2')
        if archive.exists():
            log.info('Cache for revision {} already exists'.format(self.rev))
            return
        pack(self.directory, filter(Path.exists, [self.directory/'src', self.directory/'test']), 
             archive)

    def get_cache(self, force: bool = False) -> None:
        """Tries to get olean cache.

        Will raise LeanDownloadError or FileNotFoundError if no archive exists.
        """
        if self.is_dirty and not force:
            raise LeanDirtyRepo
        if self.is_mathlib:
            self.get_mathlib_olean()
        else:
            unpack_archive(self.directory/'_cache'/(str(self.rev)+'.tar.bz2'),
                           self.directory)

    @classmethod
    def from_git_url(cls, url: str, target: str = '') -> 'LeanProject':
        """Download a Lean project using git and prepare mathlib if needed."""
        target = target or url.split('/')[-1].split('.')[0]
        repo = Repo.clone_from(url, target)
        proj = cls.from_path(Path(repo.working_dir))
        proj.run(['leanpkg', 'configure'])
        if 'mathlib' in proj.deps:
            proj.get_mathlib_olean()
        return proj
    
    @classmethod
    def new(cls, path: Path = Path('.')) -> 'LeanProject':
        """Create a new Lean project and prepare mathlib."""
        if path == Path('.'):
            subprocess.run(['leanpkg', 'init', path.absolute().name])
        else:
            subprocess.run(['leanpkg', 'new', str(path)])

        proj = cls.from_path(path)
        # Work around a leanpkg bug
        if re.match(r'^3.[5-9].*', proj.lean_version):
            proj.lean_version = 'leanprover-community/lean:' + proj.lean_version
            proj.write_config()
        proj.add_mathlib()
        return proj

    def run(self, args: List[str]) -> None:
        """Run a command in the project directory.
           
           args is a list as in subprocess.run"""
        subprocess.run(args, cwd=str(self.directory))

    def build(self) -> None:
        log.info('Building project '+self.name)
        self.run(['leanpkg', 'build'])

    def upgrade_mathlib(self) -> None:
        """Upgrade mathlib in the project.

        In case this project is mathlib, we assume we are already on the branch
        we want.
        """
        if self.is_mathlib:
            try:
                rem = next(remote for remote in self.repo.remotes 
                           if any('leanprover' in url 
                                  for url in remote.urls))
            except StopIteration:
                log.info("Couldn't find a relevant git remote. "
                         "You may try to git pull manually and then "
                         "run `leanproject get-cache`”)
                return
            rem.pull(self.repo.active_branch)
            self.rev = self.repo.commit().hexsha
        else:
            try:
                self.mathlib_folder.unlink()
            except FileNotFoundError:
                pass
            self.run(['leanpkg', 'upgrade'])
        self.get_mathlib_olean()

    def add_mathlib(self) -> None:
        """Add mathlib to the project."""
        if 'mathlib' in self.deps:
            log.info('This project already depends on  mathlib')
            return
        log.info('Adding mathlib')
        self.run(['leanpkg', 'add', 'leanprover-community/mathlib'])
        log.debug('Configuring') 
        self.run(['leanpkg', 'configure'])
        self.read_config()
        self.get_mathlib_olean()

    def setup_git_hooks(self) -> None:
        hook_dir = Path(self.repo.git_dir)/'hooks'
        src = Path(__file__).parent
        print('This script will copy post-commit and post-checkout scripts to ', hook_dir)
        rep = input("Do you want to proceed (y/n)? ")
        if rep in ['y', 'Y']:
            shutil.copy(str(src/'post-commit'), str(hook_dir))
            shutil.copy(str(src/'post-checkout'), str(hook_dir))
            print("Successfully copied scripts")
        else:
                print("Cancelled...")