/-
Copyright (c) 2018 Chris Hughes. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Chris Hughes, Johannes Hölzl, Jens Wagemaker

Theory of univariate polynomials, represented as `ℕ →₀ α`, where α is a commutative semiring.
-/
import data.finsupp algebra.euclidean_domain tactic.ring

/-- `polynomial α` is the type of univariate polynomials over `α`.

Polynomials should be seen as (semi-)rings with the additional constructor `X`.
The embedding from α is called `C`. -/
def polynomial (α : Type*) [comm_semiring α] := ℕ →₀ α

open finsupp finset lattice

namespace polynomial
universe u
variables {α : Type u} {a b : α} {m n : ℕ}
variables [decidable_eq α]

section comm_semiring
variables [comm_semiring α] {p q : polynomial α}

instance : has_coe_to_fun (polynomial α) := finsupp.has_coe_to_fun
instance : has_zero (polynomial α) := finsupp.has_zero
instance : has_one (polynomial α) := finsupp.has_one
instance : has_add (polynomial α) := finsupp.has_add
instance : has_mul (polynomial α) := finsupp.has_mul
instance : comm_semiring (polynomial α) := finsupp.to_comm_semiring
instance : decidable_eq (polynomial α) := finsupp.decidable_eq

instance [has_repr α] : has_repr (polynomial α) :=
⟨λ p, if p = 0 then "0"
  else (p.support.sort (≤)).foldr
    (λ n a, a ++ (if a = "" then "" else " + ") ++
      if n = 0
        then "C (" ++ repr (p n) ++ ")"
        else if n = 1
          then if (p n) = 1 then "X" else "C (" ++ repr (p n) ++ ") * X"
          else if (p n) = 1 then "X ^ " ++ repr n
            else "C (" ++ repr (p n) ++ ") * X ^ " ++ repr n) ""⟩

local attribute [instance] finsupp.to_comm_semiring

@[simp] lemma support_zero : (0 : polynomial α).support = ∅ := rfl

/-- `C a` is the constant polynomial `a`. -/
def C (a : α) : polynomial α := single 0 a

/-- `X` is the polynomial variable (aka indeterminant). -/
def X : polynomial α := single 1 1

/-- coeff p n is the coefficient of X^n in p -/
def coeff (p : polynomial α) (n : ℕ) := p n

theorem ext (p q : polynomial α) : p = q ↔ ∀ n, coeff p n = coeff q n :=
⟨λ h n, h ▸ rfl,finsupp.ext⟩

/-- `degree p` is the degree of the polynomial `p`, i.e. the largest `X`-exponent in `p`.
`degree p = some n` when `p ≠ 0` and `n` is the highest power of `X` that appears in `p`, otherwise
`degree 0 = ⊥`. -/
def degree (p : polynomial α) : with_bot ℕ := p.support.sup some

def degree_lt_wf : well_founded (λp q : polynomial α, degree p < degree q) :=
inv_image.wf degree (with_bot.well_founded_lt nat.lt_wf)

/-- `nat_degree p` forces `degree p` to ℕ, by defining nat_degree 0 = 0. -/
def nat_degree (p : polynomial α) : ℕ := (degree p).get_or_else 0

lemma single_eq_C_mul_X : ∀{n}, single n a = C a * X^n
| 0     := (mul_one _).symm
| (n+1) :=
  calc single (n + 1) a = single n a * X : by rw [X, single_mul_single, mul_one]
    ... = (C a * X^n) * X : by rw [single_eq_C_mul_X]
    ... = C a * X^(n+1) : by simp only [pow_add, mul_assoc, pow_one]

lemma sum_C_mul_X_eq (p : polynomial α) : p.sum (λn a, C a * X^n) = p :=
eq.trans (sum_congr rfl $ assume n hn, single_eq_C_mul_X.symm) finsupp.sum_single

@[elab_as_eliminator] protected lemma induction_on {M : polynomial α → Prop} (p : polynomial α)
  (h_C : ∀a, M (C a))
  (h_add : ∀p q, M p → M q → M (p + q))
  (h_monomial : ∀(n : ℕ) (a : α), M (C a * X^n) → M (C a * X^(n+1))) :
  M p :=
have ∀{n:ℕ} {a}, M (C a * X^n),
begin
  assume n a,
  induction n with n ih,
  { simp only [pow_zero, mul_one, h_C] },
  { exact h_monomial _ _ ih }
end,
finsupp.induction p
  (suffices M (C 0), by simpa only [C, single_zero],
    h_C 0)
  (assume n a p _ _ hp, suffices M (C a * X^n + p), by rwa [single_eq_C_mul_X],
    h_add _ _ this hp)

@[simp] lemma zero_apply (n : ℕ) : (0 : polynomial α) n = 0 := rfl

@[simp] lemma one_apply_zero (n : ℕ) : (1 : polynomial α) 0 = 1 := rfl

@[simp] lemma add_apply (p q : polynomial α) (n : ℕ) : (p + q) n = p n + q n :=
finsupp.add_apply

lemma C_apply : (C a : ℕ → α) n = ite (0 = n) a 0 := rfl

@[simp] lemma C_apply_zero : (C a : ℕ → α) 0 = a := rfl

@[simp] lemma X_apply_one : (X : polynomial α) 1 = 1 := rfl

@[simp] lemma C_0 : C (0 : α) = 0 := single_zero

@[simp] lemma C_1 : C (1 : α) = 1 := rfl

@[simp] lemma C_mul : C (a * b) = C a * C b :=
(@single_mul_single _ _ _ _ _ _ 0 0 a b).symm

@[simp] lemma C_add : C (a + b) = C a + C b := finsupp.single_add

instance C.is_semiring_hom : is_semiring_hom (C : α → polynomial α) :=
⟨C_0, C_1, λ _ _, C_add, λ _ _, C_mul⟩

@[simp] lemma C_mul_apply (p : polynomial α) : (C a * p) n = a * p n :=
begin
  conv in (a * _) { rw [← @sum_single _ _ _ _ _ p, sum_apply] },
  rw [mul_def, C, sum_single_index],
  { simp only [sum_apply, single_apply, zero_add, finsupp.mul_sum],
    apply sum_congr rfl,
    assume i hi, by_cases i = n; simp only [h, if_pos rfl, if_false, mul_zero] },
  simp only [zero_mul, single_zero], exact sum_const_zero
end

lemma C_inj : C a = C b ↔ a = b :=
⟨λ h, C_apply_zero.symm.trans (h.symm ▸ C_apply_zero), congr_arg C⟩

@[simp] lemma X_pow_apply (n i : ℕ) : (X ^ n : polynomial α) i = (if n = i then 1 else 0) :=
suffices (single n 1 : polynomial α) i = (if n = i then 1 else 0),
  by rwa [single_eq_C_mul_X, C_mul_apply, one_mul] at this,
single_apply

section coeff

@[simp] lemma coeff_zero (n : ℕ) : coeff (0 : polynomial α) n = 0 := rfl

@[simp] lemma coeff_C_mul_X (x : α) (k n : ℕ) :
  coeff (C x * X^k : polynomial α) n = if n = k then x else 0 :=
by rw [← single_eq_C_mul_X, coeff, single_apply]; split_ifs; cc

@[simp] lemma coeff_C (x : α) (n : ℕ) :
  coeff (C x) n = if n = 0 then x else 0 :=
by simpa only [pow_zero, mul_one] using coeff_C_mul_X x 0 n

@[simp] lemma coeff_one (n : ℕ) :
  coeff (1 : polynomial α) n = if n = 0 then 1 else 0 :=
coeff_C 1 n

variable α
@[simp] lemma coeff_X_pow (k n : ℕ) :
  coeff (X^k : polynomial α) n = if n = k then 1 else 0 :=
by simpa only [C_1, one_mul] using coeff_C_mul_X (1:α) k n

@[simp] lemma coeff_X (n : ℕ) :
  coeff (X : polynomial α) n = if n = 1 then 1 else 0 :=
by simpa only [pow_one] using coeff_X_pow α 1 n
variable {α}

@[simp] lemma coeff_add (p q : polynomial α) (n : ℕ) :
  coeff (p + q) n = coeff p n + coeff q n := rfl

lemma coeff_mul_left (p q : polynomial α) (n : ℕ) :
  coeff (p * q) n = (range (n+1)).sum (λ k, coeff p k * coeff q (n-k)) :=
begin
  refine polynomial.induction_on p (λ x, _) (λ p1 p2 ih1 ih2, _) (λ pn x ih, _),
  { refine polynomial.induction_on q (λ y, _) (λ q1 q2 ih1 ih2, _) (λ qn y ih, _),
    { rw [sum_eq_single 0, ← C_mul, coeff_C, coeff_C, coeff_C, if_pos rfl, nat.sub_zero],
      { by_cases h : n = 0,
        { simp only [if_pos h] },
        { simp only [if_neg h, mul_zero] } },
      { intros k h1 h2, rw [coeff_C, if_neg h2, zero_mul] },
      { exact λ h1, (h1 (mem_range.2 (nat.zero_lt_succ n))).elim } },
    { simp only [mul_add, coeff_add],
      -- why can't I just rw [ih1, ih2]???
      generalize_hyp h1 : coeff (C x * q1) n = Q1 at ih1 ⊢, rw ih1,
      generalize_hyp h2 : coeff (C x * q2) n = Q2 at ih2 ⊢, rw ih2,
      rw finset.sum_add_distrib },
    { rw [sum_eq_single 0, ← mul_assoc, ← C_mul, coeff_C_mul_X, coeff_C_mul_X, coeff_C, if_pos rfl, nat.sub_zero],
      { split_ifs; simp only [h, if_pos rfl, if_false, mul_zero] },
      { intros k h1 h2, rw [coeff_C, if_neg h2, zero_mul] },
      { exact λ h1, (h1 (mem_range.2 (nat.zero_lt_succ n))).elim } } },
  { simp only [add_mul, coeff_add],
    -- why can't I just rw [ih1, ih2]???
    generalize_hyp h1 : coeff (p1 * q) n = P1 at ih1 ⊢, rw ih1,
    generalize_hyp h2 : coeff (p2 * q) n = P2 at ih2 ⊢, rw ih2,
    rw finset.sum_add_distrib },
  { refine polynomial.induction_on q (λ y, _) (λ q1 q2 ih1 ih2, _) (λ qn y ih, _),
    { rw [sum_eq_single n, mul_right_comm, ← C_mul, coeff_C_mul_X, coeff_C_mul_X, coeff_C, if_pos (nat.sub_self _)],
      { split_ifs with h; simp only [h, if_pos rfl, if_false, zero_mul] },
      { intros k h1 h2, rw [coeff_C, if_neg, mul_zero],
        refine mt (λ H, le_antisymm (nat.le_of_lt_succ (mem_range.1 h1)) (nat.sub_eq_zero_iff_le.1 H)) h2 },
      { exact λ h1, (h1 (mem_range.2 (le_refl (n+1)))).elim } },
    { simp only [mul_add, coeff_add],
      generalize_hyp h1 : coeff (C x * X ^ (pn + 1) * q1) n = Q1 at ih1 ⊢, rw ih1,
      generalize_hyp h2 : coeff (C x * X ^ (pn + 1) * q2) n = Q2 at ih2 ⊢, rw ih2,
      rw finset.sum_add_distrib },
    { rw [mul_left_comm, mul_assoc, ← pow_add, ← mul_assoc, ← C_mul],
      rw [sum_eq_single (pn + 1), coeff_C_mul_X, coeff_C_mul_X, coeff_C_mul_X, if_pos rfl],
      { have H : n = pn + 1 + (qn + 1) ↔ n - (pn + 1) = qn + 1,
        { split, { intro H, rw [H, nat.add_sub_cancel_left] },
          intro H,
          have H1 : pn + 1 < n,
          { refine lt_of_not_ge (λ H1, _),
            rw [nat.sub_eq_zero_of_le H1] at H,
            exact nat.succ_ne_zero qn H.symm },
          rw [(nat.sub_eq_iff_eq_add (le_of_lt H1)).1 H, add_comm] },
        split_ifs with h,
        { rw [if_pos (H.1 h), mul_comm] },
        { rw [if_neg (mt H.2 h), mul_zero] } },
      { intros k h1 h2, rw [coeff_C_mul_X, if_neg h2, zero_mul] },
      { intro H,
        rw [coeff_C_mul_X, if_pos rfl, coeff_C_mul_X, if_neg, mul_zero],
        rw [mem_range, not_lt] at H,
        rw [nat.sub_eq_zero_of_le (le_of_lt H)],
        exact ne.symm (nat.succ_ne_zero _) } } }
end

lemma coeff_mul_right (p q : polynomial α) (n : ℕ) :
  coeff (p * q) n = (range (n+1)).sum (λ k, coeff p (n-k) * coeff q k) :=
by rw [mul_comm, coeff_mul_left]; simp only [mul_comm]

theorem coeff_mul_X_pow (p : polynomial α) (n d : ℕ) :
  coeff (p * polynomial.X ^ n) (d + n) = coeff p d :=
begin
  rw [coeff_mul_right, sum_eq_single n, coeff_X_pow, if_pos rfl, mul_one, nat.add_sub_cancel],
  { intros b h1 h2, rw [coeff_X_pow, if_neg h2, mul_zero] },
  { exact λ h1, (h1 (mem_range.2 (nat.le_add_left _ _))).elim }
end

theorem coeff_mul_X (p : polynomial α) (n : ℕ) :
  coeff (p * X) (n + 1) = coeff p n :=
by simpa only [pow_one] using coeff_mul_X_pow p 1 n

theorem mul_X_pow_eq_zero {p : polynomial α} {n : ℕ}
  (H : p * X ^ n = 0) : p = 0 :=
(ext _ _).2 $ λ k, (coeff_mul_X_pow p n k).symm.trans $ (ext _ _).1 H (k+n)

end coeff

section eval₂
variables {β : Type*} [comm_semiring β]
variables (f : α → β) [is_semiring_hom f] (x : β)
open is_semiring_hom

/-- Evaluate a polynomial `p` given a ring hom `f` from the scalar ring
  to the target and a value `x` for the variable in the target -/
def eval₂ (p : polynomial α) : β :=
p.sum (λ e a, f a * x ^ e)

@[simp] lemma eval₂_C : (C a).eval₂ f x = f a :=
(sum_single_index $ by rw [map_zero f, zero_mul]).trans $ by rw [pow_zero, mul_one]

@[simp] lemma eval₂_X : X.eval₂ f x = x :=
(sum_single_index $ by rw [map_zero f, zero_mul]).trans $ by rw [map_one f, one_mul, pow_one]

@[simp] lemma eval₂_zero : (0 : polynomial α).eval₂ f x = 0 :=
finsupp.sum_zero_index

@[simp] lemma eval₂_add : (p + q).eval₂ f x = p.eval₂ f x + q.eval₂ f x :=
finsupp.sum_add_index
  (λ _, by rw [map_zero f, zero_mul])
  (λ _ _ _, by rw [map_add f, add_mul])

@[simp] lemma eval₂_one : (1 : polynomial α).eval₂ f x = 1 :=
by rw [← C_1, eval₂_C, map_one f]

@[simp] lemma eval₂_mul : (p * q).eval₂ f x = p.eval₂ f x * q.eval₂ f x :=
begin
  dunfold eval₂,
  rw [mul_def, finsupp.sum_mul _ p], simp only [finsupp.mul_sum _ q], rw [sum_sum_index],
  { apply sum_congr rfl, assume i hi, dsimp only, rw [sum_sum_index],
    { apply sum_congr rfl, assume j hj, dsimp only,
      rw [sum_single_index, map_mul f, pow_add],
      { simp only [mul_assoc, mul_left_comm] },
      { rw [map_zero f, zero_mul] } },
    { intro, rw [map_zero f, zero_mul] },
    { intros, rw [map_add f, add_mul] } },
  { intro, rw [map_zero f, zero_mul] },
  { intros, rw [map_add f, add_mul] }
end

instance eval₂.is_semiring_hom : is_semiring_hom (eval₂ f x) :=
⟨eval₂_zero _ _, eval₂_one _ _, λ _ _, eval₂_add _ _, λ _ _, eval₂_mul _ _⟩

lemma eval₂_pow (n : ℕ) : (p ^ n).eval₂ f x = p.eval₂ f x ^ n := map_pow _ _ _

end eval₂

section eval
variable {x : α}

/-- `eval x p` is the evaluation of the polynomial `p` at `x` -/
def eval : α → polynomial α → α := eval₂ id

@[simp] lemma eval_C : (C a).eval x = a := eval₂_C _ _

@[simp] lemma eval_X : X.eval x = x := eval₂_X _ _

@[simp] lemma eval_zero : (0 : polynomial α).eval x = 0 :=  eval₂_zero _ _

@[simp] lemma eval_add : (p + q).eval x = p.eval x + q.eval x := eval₂_add _ _

@[simp] lemma eval_one : (1 : polynomial α).eval x = 1 := eval₂_one _ _

@[simp] lemma eval_mul : (p * q).eval x = p.eval x * q.eval x := eval₂_mul _ _

instance eval.is_semiring_hom : is_semiring_hom (eval x) := eval₂.is_semiring_hom _ _

lemma eval_pow (n : ℕ) : (p ^ n).eval x = p.eval x ^ n := eval₂_pow _ _ _

/-- `is_root p x` implies `x` is a root of `p`. The evaluation of `p` at `x` is zero -/
def is_root (p : polynomial α) (a : α) : Prop := p.eval a = 0

instance : decidable (is_root p a) := by unfold is_root; apply_instance

@[simp] lemma is_root.def : is_root p a ↔ p.eval a = 0 := iff.rfl

lemma root_mul_left_of_is_root (p : polynomial α) {q : polynomial α} :
  is_root q a → is_root (p * q) a :=
λ H, by rw [is_root, eval_mul, is_root.def.1 H, mul_zero]

lemma root_mul_right_of_is_root {p : polynomial α} (q : polynomial α) :
  is_root p a → is_root (p * q) a :=
λ H, by rw [is_root, eval_mul, is_root.def.1 H, zero_mul]

lemma eval_sum (p : polynomial α) (f : ℕ → α → polynomial α) (x : α) :
  (p.sum f).eval x = p.sum (λ n a, (f n a).eval x) :=
finsupp.sum_sum_index (by simp) (by intros; simp [right_distrib])

end eval

section map
variables {β : Type*} [comm_semiring β] [decidable_eq β]
variables (f : α → β) [is_semiring_hom f]

/-- `map f p` maps a polynomial `p` across a ring hom `f` -/
def map : polynomial α → polynomial β := eval₂ (C ∘ f) X

@[simp] lemma map_C : (C a).map f = C (f a) := eval₂_C _ _

@[simp] lemma map_X : X.map f = X := eval₂_X _ _

@[simp] lemma map_zero : (0 : polynomial α).map f = 0 :=  eval₂_zero _ _

@[simp] lemma map_add : (p + q).map f = p.map f + q.map f := eval₂_add _ _

@[simp] lemma map_one : (1 : polynomial α).map f = 1 := eval₂_one _ _

@[simp] lemma map_mul : (p * q).map f = p.map f * q.map f := eval₂_mul _ _

instance map.is_semiring_hom : is_semiring_hom (map f) := eval₂.is_semiring_hom _ _

lemma map_pow (n : ℕ) : (p ^ n).map f = p.map f ^ n := eval₂_pow _ _ _

end map

/-- `leading_coeff p` gives the coefficient of the highest power of `X` in `p`-/
def leading_coeff (p : polynomial α) : α := p (nat_degree p)

/-- a polynomial is `monic` if its leading coefficient is 1 -/
def monic (p : polynomial α) := leading_coeff p = (1 : α)

lemma monic.def : monic p ↔ leading_coeff p = 1 := iff.rfl

instance monic.decidable : decidable (monic p) :=
by unfold monic; apply_instance

@[simp] lemma degree_zero : degree (0 : polynomial α) = ⊥ := rfl

@[simp] lemma nat_degree_zero : nat_degree (0 : polynomial α) = 0 :=
rfl

@[simp] lemma degree_C (ha : a ≠ 0) : degree (C a) = (0 : with_bot ℕ) :=
show sup (ite (a = 0) ∅ {0}) some = 0,
by rw [if_neg ha]; refl

lemma degree_C_le : degree (C a) ≤ (0 : with_bot ℕ) :=
by by_cases h : a = 0; [rw [h, C_0], rw [degree_C h]]; [exact bot_le, exact le_refl _]

lemma degree_one_le : degree (1 : polynomial α) ≤ (0 : with_bot ℕ) :=
by rw [← C_1]; exact degree_C_le

lemma degree_eq_bot : degree p = ⊥ ↔ p = 0 :=
⟨λ h, by rw [degree, ← max_eq_sup_with_bot] at h;
  exact support_eq_empty.1 (max_eq_none.1 h),
λ h, h.symm ▸ rfl⟩

lemma degree_eq_nat_degree (hp : p ≠ 0) : degree p = (nat_degree p : with_bot ℕ) :=
let ⟨n, hn⟩ :=
  classical.not_forall.1 (mt option.eq_none_iff_forall_not_mem.2 (mt degree_eq_bot.1 hp)) in
have hn : degree p = some n := not_not.1 hn,
by rw [nat_degree, hn]; refl

@[simp] lemma degree_le_nat_degree : degree p ≤ nat_degree p :=
begin
  by_cases hp : p = 0, { rw [hp], exact bot_le },
  rw [degree_eq_nat_degree hp],
  exact le_refl _
end

lemma nat_degree_eq_of_degree_eq (h : degree p = degree q) : nat_degree p = nat_degree q :=
by unfold nat_degree; rw h

lemma le_degree_of_ne_zero (h : p n ≠ 0) : (n : with_bot ℕ) ≤ degree p :=
show @has_le.le (with_bot ℕ) _ (some n : with_bot ℕ) (p.support.sup some : with_bot ℕ),
from finset.le_sup ((finsupp.mem_support_iff _ _).2 h)

lemma le_nat_degree_of_ne_zero (h : p n ≠ 0) : n ≤ nat_degree p :=
begin
  rw [← with_bot.coe_le_coe, ← degree_eq_nat_degree],
  exact le_degree_of_ne_zero h,
  { assume h, subst h, exact h rfl }
end

lemma degree_le_degree (h : q (nat_degree p) ≠ 0) : degree p ≤ degree q :=
begin
  by_cases hp : p = 0,
  { rw [hp], exact bot_le },
  { rw [degree_eq_nat_degree hp], exact le_degree_of_ne_zero h }
end

@[simp] lemma nat_degree_C (a : α) : nat_degree (C a) = 0 :=
begin
  by_cases ha : a = 0,
  { have : C a = 0, { rw [ha, C_0] },
    rw [nat_degree, degree_eq_bot.2 this],
    refl },
  { rw [nat_degree, degree_C ha], refl }
end

@[simp] lemma degree_monomial (n : ℕ) (ha : a ≠ 0) : degree (C a * X ^ n) = n :=
by rw [← single_eq_C_mul_X, degree, support_single_ne_zero ha]; refl

lemma degree_monomial_le (n : ℕ) (a : α) : degree (C a * X ^ n) ≤ n :=
if h : a = 0 then by rw [h, C_0, zero_mul]; exact bot_le else le_of_eq (degree_monomial n h)

lemma eq_zero_of_degree_lt (h : degree p < n) : p n = 0 :=
not_not.1 (mt le_degree_of_ne_zero (not_le_of_gt h))

lemma apply_nat_degree_eq_zero_of_degree_lt (h : degree p < degree q) : p (nat_degree q) = 0 :=
eq_zero_of_degree_lt (lt_of_lt_of_le h degree_le_nat_degree)

lemma ne_zero_of_degree_gt {n : with_bot ℕ} (h : n < degree p) : p ≠ 0 :=
mt degree_eq_bot.2 (ne.symm (ne_of_lt (lt_of_le_of_lt bot_le h)))

lemma eq_C_of_degree_le_zero (h : degree p ≤ 0) : p = C (p 0) :=
begin
  ext n,
  cases n,
  { refl },
  { have : degree p < ↑(nat.succ n) := lt_of_le_of_lt h (with_bot.some_lt_some.2 (nat.succ_pos _)),
    rw [C_apply, if_neg (nat.succ_ne_zero _).symm, eq_zero_of_degree_lt this] }
end

lemma degree_add_le (p q : polynomial α) : degree (p + q) ≤ max (degree p) (degree q) :=
calc degree (p + q) = ((p + q).support).sup some : rfl
  ... ≤ (p.support ∪ q.support).sup some : sup_mono support_add
  ... = p.support.sup some ⊔ q.support.sup some : sup_union
  ... = _ : with_bot.sup_eq_max _ _

@[simp] lemma leading_coeff_zero : leading_coeff (0 : polynomial α) = 0 := rfl

@[simp] lemma leading_coeff_eq_zero : leading_coeff p = 0 ↔ p = 0 :=
⟨λ h, by_contradiction $ λ hp, mt (mem_support_iff _ _).1
  (not_not.2 h) (mem_of_max (degree_eq_nat_degree hp)),
λ h, h.symm ▸ leading_coeff_zero⟩

lemma leading_coeff_eq_zero_iff_deg_eq_bot : leading_coeff p = 0 ↔ degree p = ⊥ :=
by rw [leading_coeff_eq_zero, degree_eq_bot]

lemma degree_add_eq_of_degree_lt (h : degree p < degree q) : degree (p + q) = degree q :=
le_antisymm (max_eq_right_of_lt h ▸ degree_add_le _ _) $ degree_le_degree $
  begin
    rw [add_apply, apply_nat_degree_eq_zero_of_degree_lt h, zero_add],
    exact mt leading_coeff_eq_zero.1 (ne_zero_of_degree_gt h)
  end

lemma degree_add_eq_of_leading_coeff_add_ne_zero (h : leading_coeff p + leading_coeff q ≠ 0) :
  degree (p + q) = max p.degree q.degree :=
le_antisymm (degree_add_le _ _) $
  match lt_trichotomy (degree p) (degree q) with
  | or.inl hlt :=
    by rw [degree_add_eq_of_degree_lt hlt, max_eq_right_of_lt hlt]; exact le_refl _
  | or.inr (or.inl heq) :=
    le_of_not_gt $
      assume hlt : max (degree p) (degree q) > degree (p + q),
      h $ show leading_coeff p + leading_coeff q = 0,
      begin
        rw [heq, max_self] at hlt,
        rw [leading_coeff, leading_coeff, nat_degree_eq_of_degree_eq heq, ← add_apply],
        exact apply_nat_degree_eq_zero_of_degree_lt hlt
      end
  | or.inr (or.inr hlt) :=
    by rw [add_comm, degree_add_eq_of_degree_lt hlt, max_eq_left_of_lt hlt]; exact le_refl _
  end

lemma degree_erase_le (p : polynomial α) (n : ℕ) : degree (p.erase n) ≤ degree p :=
sup_mono (erase_subset _ _)

lemma degree_erase_lt (hp : p ≠ 0) : degree (p.erase (nat_degree p)) < degree p :=
lt_of_le_of_ne (degree_erase_le _ _) $
  (degree_eq_nat_degree hp).symm ▸ λ h, not_mem_erase _ _ (mem_of_max h)

lemma degree_sum_le {β : Type*} [decidable_eq β] (s : finset β) (f : β → polynomial α) :
  degree (s.sum f) ≤ s.sup (degree ∘ f) :=
finset.induction_on s (by simp only [sum_empty, sup_empty, degree_zero, le_refl]) $
  assume a s has ih,
  calc degree (sum (insert a s) f) ≤ max (degree (f a)) (degree (s.sum f)) :
    by rw sum_insert has; exact degree_add_le _ _
  ... ≤ _ : by rw [sup_insert, with_bot.sup_eq_max]; exact max_le_max (le_refl _) ih

lemma degree_mul_le (p q : polynomial α) : degree (p * q) ≤ degree p + degree q :=
calc degree (p * q) ≤ (p.support).sup (λi, degree (sum q (λj a, C (p i * a) * X ^ (i + j)))) :
    by simp only [single_eq_C_mul_X.symm]; exact degree_sum_le _ _
  ... ≤ p.support.sup (λi, q.support.sup (λj, degree (C (p i * q j) * X ^ (i + j)))) :
    finset.sup_mono_fun (assume i hi,  degree_sum_le _ _)
  ... ≤ degree p + degree q :
    begin
      refine finset.sup_le (λ a ha, finset.sup_le (λ b hb, le_trans (degree_monomial_le _ _) _)),
      rw [with_bot.coe_add],
      rw mem_support_iff at ha hb,
      exact add_le_add' (le_degree_of_ne_zero ha) (le_degree_of_ne_zero hb)
    end

lemma degree_pow_le (p : polynomial α) : ∀ n, degree (p ^ n) ≤ add_monoid.smul n (degree p)
| 0     := by rw [pow_zero, add_monoid.zero_smul]; exact degree_one_le
| (n+1) := calc degree (p ^ (n + 1)) ≤ degree p + degree (p ^ n) :
    by rw pow_succ; exact degree_mul_le _ _
  ... ≤ _ : by rw succ_smul; exact add_le_add' (le_refl _) (degree_pow_le _)

@[simp] lemma leading_coeff_monomial (a : α) (n : ℕ) : leading_coeff (C a * X ^ n) = a :=
begin
  by_cases ha : a = 0,
  { simp only [ha, C_0, zero_mul, leading_coeff_zero] },
  { rw [leading_coeff, nat_degree, degree_monomial _ ha, ← single_eq_C_mul_X],
    exact finsupp.single_eq_same }
end

@[simp] lemma leading_coeff_C (a : α) : leading_coeff (C a) = a :=
suffices leading_coeff (C a * X^0) = a, by rwa [pow_zero, mul_one] at this,
leading_coeff_monomial a 0

@[simp] lemma leading_coeff_X : leading_coeff (X : polynomial α) = 1 :=
suffices leading_coeff (C (1:α) * X^1) = 1, by rwa [C_1, pow_one, one_mul] at this,
leading_coeff_monomial 1 1

@[simp] lemma leading_coeff_one : leading_coeff (1 : polynomial α) = 1 :=
suffices leading_coeff (C (1:α) * X^0) = 1, by rwa [C_1, pow_zero, mul_one] at this,
leading_coeff_monomial 1 0

@[simp] lemma monic_one : monic (1 : polynomial α) := leading_coeff_C _

lemma leading_coeff_add_of_degree_lt (h : degree p < degree q) :
  leading_coeff (p + q) = leading_coeff q :=
have p (nat_degree q) = 0, from apply_nat_degree_eq_zero_of_degree_lt h,
by simp only [leading_coeff, nat_degree_eq_of_degree_eq (degree_add_eq_of_degree_lt h), this, add_apply, zero_add]

lemma leading_coeff_add_of_degree_eq (h : degree p = degree q)
  (hlc : leading_coeff p + leading_coeff q ≠ 0) :
  leading_coeff (p + q) = leading_coeff p + leading_coeff q :=
have nat_degree (p + q) = nat_degree p,
  by apply nat_degree_eq_of_degree_eq; rw [degree_add_eq_of_leading_coeff_add_ne_zero hlc, h, max_self],
by simp only [leading_coeff, this, nat_degree_eq_of_degree_eq h, add_apply]

@[simp] lemma mul_apply_degree_add_degree (p q : polynomial α) :
  (p * q) (nat_degree p + nat_degree q) = leading_coeff p * leading_coeff q :=
have ∀i, p i ≠ 0 → i ≠ nat_degree p →
    q.support.sum (λj, ite (i + j = nat_degree p + nat_degree q) (p i * q j) 0) = 0,
begin
  assume i hpi hid,
  rw [finset.sum_eq_single (nat_degree q), if_neg (mt add_right_cancel hid)],
  { assume j hqj hjd,
    have hi : j < nat_degree q, from lt_of_le_of_ne (le_nat_degree_of_ne_zero ((mem_support_iff _ _).1 hqj)) hjd,
    have hj : i < nat_degree p, from lt_of_le_of_ne (le_nat_degree_of_ne_zero hpi) hid,
    exact if_neg (ne_of_lt $ add_lt_add hj hi) },
  { intro, rw [if_neg (mt add_right_cancel hid)] }
end,
begin
  rw [mul_def, sum_apply, finsupp.sum, finset.sum_eq_single (nat_degree p),
      sum_apply, finsupp.sum, finset.sum_eq_single (nat_degree q),
      single_apply, if_pos rfl, leading_coeff, leading_coeff],
  { intros j hjq hjd, rw [single_apply, if_neg (mt add_left_cancel hjd)] },
  { intro H, rw [single_eq_same, by_contradiction (mt (mem_support_iff _ _).2 H), mul_zero] },
  { simpa only [mem_support_iff, sum_apply, single_apply] },
  { intro H, simp only [sum_apply, single_apply, by_contradiction (mt (mem_support_iff _ _).2 H), zero_mul, if_t_t], exact sum_const_zero }
end

lemma degree_mul_eq' (h : leading_coeff p * leading_coeff q ≠ 0) :
  degree (p * q) = degree p + degree q :=
have hp : p ≠ 0 := by refine mt _ h; exact λ hp, by rw [hp, leading_coeff_zero, zero_mul],
have hq : q ≠ 0 := by refine mt _ h; exact λ hq, by rw [hq, leading_coeff_zero, mul_zero],
le_antisymm (degree_mul_le _ _)
begin
  rw [degree_eq_nat_degree hp, degree_eq_nat_degree hq],
  refine le_degree_of_ne_zero _,
  rwa mul_apply_degree_add_degree
end

lemma nat_degree_mul_eq' (h : leading_coeff p * leading_coeff q ≠ 0) :
  nat_degree (p * q) = nat_degree p + nat_degree q :=
have hp : p ≠ 0 := mt leading_coeff_eq_zero.2 (λ h₁, h $ by rw [h₁, zero_mul]),
have hq : q ≠ 0 := mt leading_coeff_eq_zero.2 (λ h₁, h $ by rw [h₁, mul_zero]),
have hpq : p * q ≠ 0 := λ hpq, by rw [← mul_apply_degree_add_degree, hpq, zero_apply] at h;
  exact h rfl,
option.some_inj.1 (show (nat_degree (p * q) : with_bot ℕ) = nat_degree p + nat_degree q,
  by rw [← degree_eq_nat_degree hpq, degree_mul_eq' h, degree_eq_nat_degree hp, degree_eq_nat_degree hq])

lemma leading_coeff_mul' (h : leading_coeff p * leading_coeff q ≠ 0) :
  leading_coeff (p * q) = leading_coeff p * leading_coeff q :=
begin
  unfold leading_coeff,
  rw [nat_degree_mul_eq' h, mul_apply_degree_add_degree],
  refl
end

lemma leading_coeff_pow' : leading_coeff p ^ n ≠ 0 →
  leading_coeff (p ^ n) = leading_coeff p ^ n :=
nat.rec_on n (by simp) $
λ n ih h,
have h₁ : leading_coeff p ^ n ≠ 0 :=
  λ h₁, h $ by rw [pow_succ, h₁, mul_zero],
have h₂ : leading_coeff p * leading_coeff (p ^ n) ≠ 0 :=
  by rwa [pow_succ, ← ih h₁] at h,
by rw [pow_succ, pow_succ, leading_coeff_mul' h₂, ih h₁]

lemma degree_pow_eq' : ∀ {n}, leading_coeff p ^ n ≠ 0 →
  degree (p ^ n) = add_monoid.smul n (degree p)
| 0     := λ h, by rw [pow_zero, ← C_1] at *;
  rw [degree_C h, add_monoid.zero_smul]
| (n+1) := λ h,
have h₁ : leading_coeff p ^ n ≠ 0 := λ h₁, h $
  by rw [pow_succ, h₁, mul_zero],
have h₂ : leading_coeff p * leading_coeff (p ^ n) ≠ 0 :=
  by rwa [pow_succ, ← leading_coeff_pow' h₁] at h,
by rw [pow_succ, degree_mul_eq' h₂, succ_smul, degree_pow_eq' h₁]

@[simp] lemma leading_coeff_X_pow : ∀ n : ℕ, leading_coeff ((X : polynomial α) ^ n) = 1
| 0 := by simp
| (n+1) :=
if h10 : (1 : α) = 0
then by rw [pow_succ, ← one_mul X, ← C_1, h10]; simp
else
have h : leading_coeff (X : polynomial α) * leading_coeff (X ^ n) ≠ 0,
  by rw [leading_coeff_X, leading_coeff_X_pow n, one_mul];
    exact h10,
by rw [pow_succ, leading_coeff_mul' h, leading_coeff_X, leading_coeff_X_pow, one_mul]

end comm_semiring

section comm_ring
variables [comm_ring α] {p q : polynomial α}
instance : comm_ring (polynomial α) := finsupp.to_comm_ring
instance : has_scalar α (polynomial α) := finsupp.to_has_scalar
-- TODO if this becomes a semimodule then the below lemma could be proved for semimodules
instance : module α (polynomial α) := finsupp.to_module α

-- TODO -- this is OK for semimodules
@[simp] lemma coeff_smul (p : polynomial α) (r : α) (n : ℕ) :
coeff (r • p) n = r * coeff p n := finsupp.smul_apply

-- TODO -- this is OK for semimodules
lemma C_mul' (a : α) (f : polynomial α) : C a * f = a • f :=
(ext _ _).2 $ λ n, C_mul_apply f

-- TODO -- this is OK for semimodules
lemma coeff_is_linear (n : ℕ) : is_linear_map (λ f : polynomial α, coeff f n) := {
  add := λ f g, coeff_add f g n,
  smul := λ r p, coeff_smul p r n
}
instance C.is_ring_hom : is_ring_hom (@C α _ _) := by apply is_ring_hom.of_semiring

instance eval₂.is_ring_hom {β} [comm_ring β]
  (f : α → β) [is_ring_hom f] {x : β} : is_ring_hom (eval₂ f x) :=
by apply is_ring_hom.of_semiring

instance eval.is_ring_hom {x : α} : is_ring_hom (eval x) := eval₂.is_ring_hom _

instance map.is_ring_hom {β} [comm_ring β] [decidable_eq β]
  (f : α → β) [is_ring_hom f] : is_ring_hom (map f) :=
eval₂.is_ring_hom (C ∘ f)

@[simp] lemma degree_neg (p : polynomial α) : degree (-p) = degree p :=
by unfold degree; rw support_neg

@[simp] lemma neg_apply (p : polynomial α) (n : ℕ) : (-p) n = -p n := neg_apply

@[simp] lemma eval_neg (p : polynomial α) (x : α) : (-p).eval x = -p.eval x :=
is_ring_hom.map_neg _

@[simp] lemma eval_sub (p q : polynomial α) (x : α) : (p - q).eval x = p.eval x - q.eval x :=
is_ring_hom.map_sub _

lemma degree_sub_lt (hd : degree p = degree q)
  (hp0 : p ≠ 0) (hlc : leading_coeff p = leading_coeff q) :
  degree (p - q) < degree p :=
have hp : single (nat_degree p) (leading_coeff p) + p.erase (nat_degree p) = p :=
  finsupp.single_add_erase,
have hq : single (nat_degree q) (leading_coeff q) + q.erase (nat_degree q) = q :=
  finsupp.single_add_erase,
have hd' : nat_degree p = nat_degree q := by unfold nat_degree; rw hd,
have hq0 : q ≠ 0 := mt degree_eq_bot.2 (hd ▸ mt degree_eq_bot.1 hp0),
calc degree (p - q) = degree (erase (nat_degree q) p + -erase (nat_degree q) q) :
  by conv {to_lhs, rw [← hp, ← hq, hlc, hd', add_sub_add_left_eq_sub, sub_eq_add_neg]}
... ≤ max (degree (erase (nat_degree q) p)) (degree (erase (nat_degree q) q))
  : degree_neg (erase (nat_degree q) q) ▸ degree_add_le _ _
... < degree p : max_lt_iff.2 ⟨hd' ▸ degree_erase_lt hp0, hd.symm ▸ degree_erase_lt hq0⟩

instance : has_well_founded (polynomial α) := ⟨_, degree_lt_wf⟩

lemma ne_zero_of_ne_zero_of_monic (hp : p ≠ 0) (hq : monic q) : q ≠ 0
| h := begin
  rw [h, monic.def, leading_coeff_zero] at hq,
  rw [← mul_one p, ← C_1, ← hq, C_0, mul_zero] at hp,
  exact hp rfl
end

lemma div_wf_lemma (h : degree q ≤ degree p ∧ p ≠ 0) (hq : monic q) :
  degree (p - C (leading_coeff p) * X ^ (nat_degree p - nat_degree q) * q) < degree p :=
have hp : leading_coeff p ≠ 0 := mt leading_coeff_eq_zero.1 h.2,
have hpq : leading_coeff (C (leading_coeff p) * X ^ (nat_degree p - nat_degree q)) *
    leading_coeff q ≠ 0,
  by rwa [leading_coeff_monomial, monic.def.1 hq, mul_one],
if h0 : p - C (leading_coeff p) * X ^ (nat_degree p - nat_degree q) * q = 0
then h0.symm ▸ (lt_of_not_ge $ mt le_bot_iff.1 (mt degree_eq_bot.1 h.2))
else
  have hq0 : q ≠ 0 := ne_zero_of_ne_zero_of_monic h.2 hq,
  have hlt : nat_degree q ≤ nat_degree p := with_bot.coe_le_coe.1
    (by rw [← degree_eq_nat_degree h.2, ← degree_eq_nat_degree hq0];
    exact h.1),
  degree_sub_lt
  (by rw [degree_mul_eq' hpq, degree_monomial _ hp, degree_eq_nat_degree h.2,
      degree_eq_nat_degree hq0, ← with_bot.coe_add, nat.sub_add_cancel hlt])
  h.2
  (by rw [leading_coeff_mul' hpq, leading_coeff_monomial, monic.def.1 hq, mul_one])

def div_mod_by_monic_aux : Π (p : polynomial α) {q : polynomial α},
  monic q → polynomial α × polynomial α
| p := λ q hq, if h : degree q ≤ degree p ∧ p ≠ 0 then
  let z := C (leading_coeff p) * X^(nat_degree p - nat_degree q)  in
  have wf : _ := div_wf_lemma h hq,
  let dm := div_mod_by_monic_aux (p - z * q) hq in
  ⟨z + dm.1, dm.2⟩
  else ⟨0, p⟩
using_well_founded {dec_tac := tactic.assumption}

/-- `div_by_monic` gives the quotient of `p` by a monic polynomial `q`. -/
def div_by_monic (p q : polynomial α) : polynomial α :=
if hq : monic q then (div_mod_by_monic_aux p hq).1 else 0

/-- `mod_by_monic` gives the remainder of `p` by a monic polynomial `q`. -/
def mod_by_monic (p q : polynomial α) : polynomial α :=
if hq : monic q then (div_mod_by_monic_aux p hq).2 else p

infixl  ` /ₘ ` : 70 := div_by_monic

infixl ` %ₘ ` : 70 := mod_by_monic

lemma degree_mod_by_monic_lt : ∀ (p : polynomial α) {q : polynomial α} (hq : monic q)
  (hq0 : q ≠ 0), degree (p %ₘ q) < degree q
| p := λ q hq hq0,
if h : degree q ≤ degree p ∧ p ≠ 0 then
  have wf : _ := div_wf_lemma ⟨h.1, h.2⟩ hq,
  have degree ((p - C (leading_coeff p) * X ^ (nat_degree p - nat_degree q) * q) %ₘ q) < degree q :=
      degree_mod_by_monic_lt (p - C (leading_coeff p) * X ^ (nat_degree p - nat_degree q) * q)
      hq hq0,
  begin
    unfold mod_by_monic at this ⊢,
    unfold div_mod_by_monic_aux,
    rw dif_pos hq at this ⊢,
    rw if_pos h,
    exact this
  end
else
  or.cases_on (not_and_distrib.1 h) begin
    unfold mod_by_monic div_mod_by_monic_aux,
    rw [dif_pos hq, if_neg h],
    exact lt_of_not_ge,
  end
  begin
    assume hp,
    unfold mod_by_monic div_mod_by_monic_aux,
    rw [dif_pos hq, if_neg h, not_not.1 hp],
    exact lt_of_le_of_ne bot_le
      (ne.symm (mt degree_eq_bot.1 hq0)),
  end
using_well_founded {dec_tac := tactic.assumption}

lemma mod_by_monic_eq_sub_mul_div : ∀ (p : polynomial α) {q : polynomial α} (hq : monic q),
  p %ₘ q = p - q * (p /ₘ q)
| p := λ q hq,
  if h : degree q ≤ degree p ∧ p ≠ 0 then
    have wf : _ := div_wf_lemma h hq,
    have ih : _ := mod_by_monic_eq_sub_mul_div
      (p - C (leading_coeff p) * X ^ (nat_degree p - nat_degree q) * q) hq,
    begin
      unfold mod_by_monic div_by_monic div_mod_by_monic_aux,
      rw [dif_pos hq, if_pos h],
      rw [mod_by_monic, dif_pos hq] at ih,
      refine ih.trans _,
      unfold div_by_monic,
      rw [dif_pos hq, dif_pos hq, if_pos h, mul_add, sub_add_eq_sub_sub, mul_comm]
    end
  else
    begin
      unfold mod_by_monic div_by_monic div_mod_by_monic_aux,
      rw [dif_pos hq, if_neg h, dif_pos hq, if_neg h, mul_zero, sub_zero]
    end
using_well_founded {dec_tac := tactic.assumption}

lemma subsingleton_of_monic_zero (h : monic (0 : polynomial α)) :
  (∀ p q : polynomial α, p = q) ∧ (∀ a b : α, a = b) :=
by rw [monic.def, leading_coeff_zero] at h;
  exact ⟨λ p q, by rw [← mul_one p, ← mul_one q, ← C_1, ← h, C_0, mul_zero, mul_zero],
    λ a b, by rw [← mul_one a, ← mul_one b, ← h, mul_zero, mul_zero]⟩

lemma mod_by_monic_add_div (p : polynomial α) {q : polynomial α} (hq : monic q) :
  p %ₘ q + q * (p /ₘ q) = p := eq_sub_iff_add_eq.1 (mod_by_monic_eq_sub_mul_div p hq)

@[simp] lemma zero_mod_by_monic (p : polynomial α) : 0 %ₘ p = 0 :=
begin
  unfold mod_by_monic div_mod_by_monic_aux,
  by_cases hp : monic p,
  { rw [dif_pos hp, if_neg (mt and.right (not_not_intro rfl))] },
  { rw [dif_neg hp] }
end

@[simp] lemma zero_div_by_monic (p : polynomial α) : 0 /ₘ p = 0 :=
begin
  unfold div_by_monic div_mod_by_monic_aux,
  by_cases hp : monic p,
  { rw [dif_pos hp, if_neg (mt and.right (not_not_intro rfl))] },
  { rw [dif_neg hp] }
end

@[simp] lemma mod_by_monic_zero (p : polynomial α) : p %ₘ 0 = p :=
if h : monic (0 : polynomial α) then (subsingleton_of_monic_zero h).1 _ _ else
by unfold mod_by_monic div_mod_by_monic_aux; rw dif_neg h

@[simp] lemma div_by_monic_zero (p : polynomial α) : p /ₘ 0 = 0 :=
if h : monic (0 : polynomial α) then (subsingleton_of_monic_zero h).1 _ _ else
by unfold div_by_monic div_mod_by_monic_aux; rw dif_neg h

lemma div_by_monic_eq_of_not_monic (p : polynomial α) (hq : ¬monic q) : p /ₘ q = 0 := dif_neg hq

lemma mod_by_monic_eq_of_not_monic (p : polynomial α) (hq : ¬monic q) : p %ₘ q = p := dif_neg hq

lemma mod_by_monic_eq_self_iff (hq : monic q) (hq0 : q ≠ 0) : p %ₘ q = p ↔ degree p < degree q :=
⟨λ h, h ▸ degree_mod_by_monic_lt _ hq hq0,
λ h, have ¬ degree q ≤ degree p := not_le_of_gt h,
  by unfold mod_by_monic div_mod_by_monic_aux; rw [dif_pos hq, if_neg (mt and.left this)]⟩

lemma div_by_monic_eq_zero_iff (hq : monic q) (hq0 : q ≠ 0) : p /ₘ q = 0 ↔ degree p < degree q :=
⟨λ h, by have := mod_by_monic_add_div p hq;
  rwa [h, mul_zero, add_zero, mod_by_monic_eq_self_iff hq hq0] at this,
λ h, have ¬ degree q ≤ degree p := not_le_of_gt h,
  by unfold div_by_monic div_mod_by_monic_aux; rw [dif_pos hq, if_neg (mt and.left this)]⟩

lemma degree_add_div_by_monic (hq : monic q) (h : degree q ≤ degree p) :
  degree q + degree (p /ₘ q) = degree p :=
if hq0 : q = 0 then
  have ∀ (p : polynomial α), p = 0,
    from λ p, (@subsingleton_of_monic_zero α _ _ (hq0 ▸ hq)).1 _ _,
  by rw [this (p /ₘ q), this p, this q]; refl
else
have hdiv0 : p /ₘ q ≠ 0 := by rwa [(≠), div_by_monic_eq_zero_iff hq hq0, not_lt],
have hlc : leading_coeff q * leading_coeff (p /ₘ q) ≠ 0 :=
  by rwa [monic.def.1 hq, one_mul, (≠), leading_coeff_eq_zero],
have hmod : degree (p %ₘ q) < degree (q * (p /ₘ q)) :=
  calc degree (p %ₘ q) < degree q : degree_mod_by_monic_lt _ hq hq0
  ... ≤ _ : by rw [degree_mul_eq' hlc, degree_eq_nat_degree hq0,
      degree_eq_nat_degree hdiv0, ← with_bot.coe_add, with_bot.coe_le_coe];
    exact nat.le_add_right _ _,
calc degree q + degree (p /ₘ q) = degree (q * (p /ₘ q)) : eq.symm (degree_mul_eq' hlc)
... = degree (p %ₘ q + q * (p /ₘ q)) : (degree_add_eq_of_degree_lt hmod).symm
... = _ : congr_arg _ (mod_by_monic_add_div _ hq)

lemma degree_div_by_monic_le (p q : polynomial α) : degree (p /ₘ q) ≤ degree p :=
if hp0 : p = 0 then by simp only [hp0, zero_div_by_monic, le_refl]
else if hq : monic q then
  have hq0 : q ≠ 0 := ne_zero_of_ne_zero_of_monic hp0 hq,
  if h : degree q ≤ degree p
  then by rw [← degree_add_div_by_monic hq h, degree_eq_nat_degree hq0,
      degree_eq_nat_degree (mt (div_by_monic_eq_zero_iff hq hq0).1 (not_lt.2 h))];
    exact with_bot.coe_le_coe.2 (nat.le_add_left _ _)
  else
    by unfold div_by_monic div_mod_by_monic_aux;
      simp only [dif_pos hq, h, false_and, if_false, degree_zero, bot_le]
else (div_by_monic_eq_of_not_monic p hq).symm ▸ bot_le

lemma degree_div_by_monic_lt (p : polynomial α) {q : polynomial α} (hq : monic q)
  (hp0 : p ≠ 0) (h0q : 0 < degree q) : degree (p /ₘ q) < degree p :=
have hq0 : q ≠ 0 := ne_zero_of_ne_zero_of_monic hp0 hq,
if hpq : degree p < degree q
then begin
  rw [(div_by_monic_eq_zero_iff hq hq0).2 hpq, degree_eq_nat_degree hp0],
  exact with_bot.bot_lt_some _
end
else begin
  rw [← degree_add_div_by_monic hq (not_lt.1 hpq), degree_eq_nat_degree hq0,
        degree_eq_nat_degree (mt (div_by_monic_eq_zero_iff hq hq0).1 hpq)],
  exact with_bot.coe_lt_coe.2 (nat.lt_add_of_pos_left
    (with_bot.coe_lt_coe.1 $ (degree_eq_nat_degree hq0) ▸ h0q))
end

lemma dvd_iff_mod_by_monic_eq_zero (hq : monic q) : p %ₘ q = 0 ↔ q ∣ p :=
⟨λ h, by rw [← mod_by_monic_add_div p hq, h, zero_add];
  exact dvd_mul_right _ _,
λ h, if hq0 : q = 0 then by rw hq0 at hq;
  exact (subsingleton_of_monic_zero hq).1 _ _
  else
  let ⟨r, hr⟩ := exists_eq_mul_right_of_dvd h in
  by_contradiction (λ hpq0,
  have hmod : p %ₘ q = q * (r - p /ₘ q) :=
    by rw [mod_by_monic_eq_sub_mul_div _ hq, mul_sub, ← hr],
  have degree (q * (r - p /ₘ q)) < degree q :=
    hmod ▸ degree_mod_by_monic_lt _ hq hq0,
  have hrpq0 : leading_coeff (r - p /ₘ q) ≠ 0 :=
    λ h, hpq0 $ leading_coeff_eq_zero.1
      (by rw [hmod, leading_coeff_eq_zero.1 h, mul_zero, leading_coeff_zero]),
  have hlc : leading_coeff q * leading_coeff (r - p /ₘ q) ≠ 0 :=
    by rwa [monic.def.1 hq, one_mul],
  by rw [degree_mul_eq' hlc, degree_eq_nat_degree hq0,
      degree_eq_nat_degree (mt leading_coeff_eq_zero.2 hrpq0)] at this;
    exact not_lt_of_ge (nat.le_add_right _ _) (with_bot.some_lt_some.1 this))⟩

end comm_ring

section nonzero_comm_ring
variables [nonzero_comm_ring α] {p q : polynomial α}

instance : nonzero_comm_ring (polynomial α) :=
{ zero_ne_one := λ (h : (0 : polynomial α) = 1),
    @zero_ne_one α _ $
    calc (0 : α) = eval 0 0 : eval_zero.symm
      ... = eval 0 1 : congr_arg _ h
      ... = 1 : eval_C,
  ..polynomial.comm_ring }

@[simp] lemma degree_one : degree (1 : polynomial α) = (0 : with_bot ℕ) :=
degree_C (show (1 : α) ≠ 0, from zero_ne_one.symm)

@[simp] lemma degree_X : degree (X : polynomial α) = 1 :=
begin
  unfold X degree single finsupp.support,
  rw if_neg (zero_ne_one).symm,
  refl
end

@[simp] lemma degree_X_sub_C (a : α) : degree (X - C a) = 1 :=
begin
  rw [sub_eq_add_neg, add_comm, ← @degree_X α],
  by_cases ha : a = 0,
  { simp only [ha, C_0, neg_zero, zero_add] },
  exact degree_add_eq_of_degree_lt (by rw [degree_X, degree_neg, degree_C ha]; exact dec_trivial)
end

@[simp] lemma degree_X_pow : ∀ (n : ℕ), degree ((X : polynomial α) ^ n) = n
| 0 := by simp only [pow_zero, degree_one]; refl
| (n+1) :=
have h : leading_coeff (X : polynomial α) * leading_coeff (X ^ n) ≠ 0,
  by rw [leading_coeff_X, leading_coeff_X_pow n, one_mul];
    exact zero_ne_one.symm,
by rw [pow_succ, degree_mul_eq' h, degree_X, degree_X_pow, add_comm]; refl

lemma degree_X_pow_sub_C {n : ℕ} (hn : 0 < n) (a : α) :
  degree ((X : polynomial α) ^ n - C a) = n :=
have degree (-C a) < degree ((X : polynomial α) ^ n),
  from calc degree (-C a) ≤ 0 : by rw degree_neg; exact degree_C_le
  ... < degree ((X : polynomial α) ^ n) : by rwa [degree_X_pow];
    exact with_bot.coe_lt_coe.2 hn,
by rw [sub_eq_add_neg, add_comm, degree_add_eq_of_degree_lt this, degree_X_pow]

lemma X_pow_sub_C_ne_zero {n : ℕ} (hn : 0 < n) (a : α) :
  (X : polynomial α) ^ n - C a ≠ 0 :=
mt degree_eq_bot.2 (show degree ((X : polynomial α) ^ n - C a) ≠ ⊥,
  by rw degree_X_pow_sub_C hn; exact dec_trivial)

@[simp] lemma not_monic_zero : ¬monic (0 : polynomial α) :=
by simpa only [monic, leading_coeff_zero] using zero_ne_one

lemma ne_zero_of_monic (h : monic p) : p ≠ 0 :=
λ h₁, @not_monic_zero α _ _ (h₁ ▸ h)

lemma monic_X_sub_C (a : α) : monic (X - C a) :=
have degree (-C a) < degree (X : polynomial α) :=
if ha : a = 0
  then by simp only [ha, degree_zero, C_0, degree_X, neg_zero]; exact with_bot.bot_lt_some _
  else by simp only [degree_C ha, degree_neg, degree_X]; exact dec_trivial,
by unfold monic;
  rw [sub_eq_add_neg, add_comm, leading_coeff_add_of_degree_lt this, leading_coeff_X]

lemma root_X_sub_C : is_root (X - C a) b ↔ a = b :=
by rw [is_root.def, eval_sub, eval_X, eval_C, sub_eq_zero_iff_eq, eq_comm]

@[simp] lemma mod_by_monic_X_sub_C_eq_C_eval (p : polynomial α) (a : α) : p %ₘ (X - C a) = C (p.eval a) :=
have h : (p %ₘ (X - C a)).eval a = p.eval a :=
  by rw [mod_by_monic_eq_sub_mul_div _ (monic_X_sub_C a), eval_sub, eval_mul,
    eval_sub, eval_X, eval_C, sub_self, zero_mul, sub_zero],
have degree (p %ₘ (X - C a)) < 1 :=
  degree_X_sub_C a ▸ degree_mod_by_monic_lt p (monic_X_sub_C a) ((degree_X_sub_C a).symm ▸
    ne_zero_of_monic (monic_X_sub_C _)),
have degree (p %ₘ (X - C a)) ≤ 0 :=
  begin
    cases (degree (p %ₘ (X - C a))),
    { exact bot_le },
    { exact with_bot.some_le_some.2 (nat.le_of_lt_succ (with_bot.some_lt_some.1 this)) }
  end,
begin
  rw [eq_C_of_degree_le_zero this, eval_C] at h,
  rw [eq_C_of_degree_le_zero this, h]
end

lemma mul_div_by_monic_eq_iff_is_root : (X - C a) * (p /ₘ (X - C a)) = p ↔ is_root p a :=
⟨λ h, by rw [← h, is_root.def, eval_mul, eval_sub, eval_X, eval_C, sub_self, zero_mul],
λ h : p.eval a = 0,
  by conv {to_rhs, rw ← mod_by_monic_add_div p (monic_X_sub_C a)};
    rw [mod_by_monic_X_sub_C_eq_C_eval, h, C_0, zero_add]⟩

lemma dvd_iff_is_root : (X - C a) ∣ p ↔ is_root p a :=
⟨λ h, by rwa [← dvd_iff_mod_by_monic_eq_zero (monic_X_sub_C _),
    mod_by_monic_X_sub_C_eq_C_eval, ← C_0, C_inj] at h,
  λ h, ⟨(p /ₘ (X - C a)), by rw mul_div_by_monic_eq_iff_is_root.2 h⟩⟩

end nonzero_comm_ring

section integral_domain
variables [integral_domain α] {p q : polynomial α}

@[simp] lemma degree_mul_eq : degree (p * q) = degree p + degree q :=
if hp0 : p = 0 then by simp only [hp0, degree_zero, zero_mul, with_bot.bot_add]
else if hq0 : q = 0 then  by simp only [hq0, degree_zero, mul_zero, with_bot.add_bot]
else degree_mul_eq' $ mul_ne_zero (mt leading_coeff_eq_zero.1 hp0)
    (mt leading_coeff_eq_zero.1 hq0)

@[simp] lemma degree_pow_eq (p : polynomial α) (n : ℕ) :
  degree (p ^ n) = add_monoid.smul n (degree p) :=
by induction n; [simp only [pow_zero, degree_one, add_monoid.zero_smul],
simp only [*, pow_succ, succ_smul, degree_mul_eq]]

@[simp] lemma leading_coeff_mul (p q : polynomial α) : leading_coeff (p * q) =
  leading_coeff p * leading_coeff q :=
begin
  by_cases hp : p = 0,
  { simp only [hp, zero_mul, leading_coeff_zero] },
  { by_cases hq : q = 0,
    { simp only [hq, mul_zero, leading_coeff_zero] },
    { rw [leading_coeff_mul'],
      exact mul_ne_zero (mt leading_coeff_eq_zero.1 hp) (mt leading_coeff_eq_zero.1 hq) } }
end

@[simp] lemma leading_coeff_pow (p : polynomial α) (n : ℕ) :
  leading_coeff (p ^ n) = leading_coeff p ^ n :=
by induction n; [simp only [pow_zero, leading_coeff_one],
simp only [*, pow_succ, leading_coeff_mul]]

instance : integral_domain (polynomial α) :=
{ eq_zero_or_eq_zero_of_mul_eq_zero := λ a b h, begin
    have : leading_coeff 0 = leading_coeff a * leading_coeff b := h ▸ leading_coeff_mul a b,
    rw [leading_coeff_zero, eq_comm] at this,
    rw [← leading_coeff_eq_zero, ← leading_coeff_eq_zero],
    exact eq_zero_or_eq_zero_of_mul_eq_zero this
  end,
  ..polynomial.nonzero_comm_ring }

lemma root_or_root_of_root_mul (h : is_root (p * q) a) : is_root p a ∨ is_root q a :=
by rw [is_root, eval_mul] at h;
  exact eq_zero_or_eq_zero_of_mul_eq_zero h

lemma degree_pos_of_root (hp : p ≠ 0) (h : is_root p a) : 0 < degree p :=
lt_of_not_ge $ λ hlt, begin
  have := eq_C_of_degree_le_zero hlt,
  rw [is_root, this, eval_C] at h,
  exact hp (finsupp.ext (λ n, show p n = 0, from
    nat.cases_on n h (λ _, eq_zero_of_degree_lt (lt_of_le_of_lt hlt
      (with_bot.coe_lt_coe.2 (nat.succ_pos _)))))),
end

lemma degree_le_mul_left (p : polynomial α) (hq : q ≠ 0) : degree p ≤ degree (p * q) :=
if hp : p = 0 then by simp only [hp, zero_mul, le_refl]
else by rw [degree_mul_eq, degree_eq_nat_degree hp,
    degree_eq_nat_degree hq];
  exact with_bot.coe_le_coe.2 (nat.le_add_right _ _)

lemma exists_finset_roots : ∀ {p : polynomial α} (hp : p ≠ 0),
  ∃ s : finset α, (s.card : with_bot ℕ) ≤ degree p ∧ ∀ x, x ∈ s ↔ is_root p x
| p := λ hp, by haveI := classical.prop_decidable (∃ x, is_root p x); exact
if h : ∃ x, is_root p x
then
  let ⟨x, hx⟩ := h in
  have hpd : 0 < degree p := degree_pos_of_root hp hx,
  have hd0 : p /ₘ (X - C x) ≠ 0 :=
    λ h, by rw [← mul_div_by_monic_eq_iff_is_root.2 hx, h, mul_zero] at hp; exact hp rfl,
  have wf : degree (p /ₘ _) < degree p :=
    degree_div_by_monic_lt _ (monic_X_sub_C x) hp
    ((degree_X_sub_C x).symm ▸ dec_trivial),
  let ⟨t, htd, htr⟩ := @exists_finset_roots (p /ₘ (X - C x)) hd0 in
  have hdeg : degree (X - C x) ≤ degree p := begin
    rw [degree_X_sub_C, degree_eq_nat_degree hp],
    rw degree_eq_nat_degree hp at hpd,
    exact with_bot.coe_le_coe.2 (with_bot.coe_lt_coe.1 hpd)
  end,
  have hdiv0 : p /ₘ (X - C x) ≠ 0 := mt (div_by_monic_eq_zero_iff (monic_X_sub_C x)
    (ne_zero_of_monic (monic_X_sub_C x))).1 $ not_lt.2 hdeg,
  ⟨insert x t, calc (card (insert x t) : with_bot ℕ) ≤ card t + 1 :
    with_bot.coe_le_coe.2 $ finset.card_insert_le _ _
    ... ≤ degree p :
      by rw [← degree_add_div_by_monic (monic_X_sub_C x) hdeg,
          degree_X_sub_C, add_comm];
        exact add_le_add' (le_refl (1 : with_bot ℕ)) htd,
  begin
    assume y,
    rw [mem_insert, htr, eq_comm, ← root_X_sub_C],
    conv {to_rhs, rw ← mul_div_by_monic_eq_iff_is_root.2 hx},
    exact ⟨λ h, or.cases_on h (root_mul_right_of_is_root _) (root_mul_left_of_is_root _),
      root_or_root_of_root_mul⟩
  end⟩
else
  ⟨∅, (degree_eq_nat_degree hp).symm ▸ with_bot.coe_le_coe.2 (nat.zero_le _),
    by simpa only [not_mem_empty, false_iff, not_exists] using h⟩
using_well_founded {dec_tac := tactic.assumption}

/-- `roots p` noncomputably gives a finset containing all the roots of `p` -/
noncomputable def roots (p : polynomial α) : finset α :=
if h : p = 0 then ∅ else classical.some (exists_finset_roots h)

lemma card_roots (hp0 : p ≠ 0) : ((roots p).card : with_bot ℕ) ≤ degree p :=
begin
  unfold roots,
  rw dif_neg hp0,
  exact (classical.some_spec (exists_finset_roots hp0)).1
end

@[simp] lemma mem_roots (hp : p ≠ 0) : a ∈ p.roots ↔ is_root p a :=
by unfold roots; rw dif_neg hp; exact (classical.some_spec (exists_finset_roots hp)).2 _

lemma card_roots_X_pow_sub_C {n : ℕ} (hn : 0 < n) (a : α) :
  (roots ((X : polynomial α) ^ n - C a)).card ≤ n :=
with_bot.coe_le_coe.1 $
calc ((roots ((X : polynomial α) ^ n - C a)).card : with_bot ℕ)
      ≤ degree ((X : polynomial α) ^ n - C a) : card_roots (X_pow_sub_C_ne_zero hn a)
  ... = n : degree_X_pow_sub_C hn a

/-- `nth_roots n a` noncomputably returns the solutions to `x ^ n = a`-/
noncomputable def nth_roots {α : Type*} [integral_domain α] (n : ℕ) (a : α) : finset α :=
by letI := classical.prop_decidable; exact
roots ((X : polynomial α) ^ n - C a)

@[simp] lemma mem_nth_roots {α : Type*} [integral_domain α] {n : ℕ} (hn : 0 < n) {a x : α} :
  x ∈ nth_roots n a ↔ x ^ n = a :=
by letI := classical.prop_decidable;
rw [nth_roots, mem_roots (X_pow_sub_C_ne_zero hn a),
  is_root.def, eval_sub, eval_C, eval_pow, eval_X, sub_eq_zero_iff_eq]

lemma card_nth_roots {α : Type*} [integral_domain α] (n : ℕ) (a : α) :
  (nth_roots n a).card ≤ n :=
by letI := classical.prop_decidable; exact
if hn : n = 0
then if h : (X : polynomial α) ^ n - C a = 0
  then by simp only [nat.zero_le, nth_roots, roots, h, dif_pos rfl, card_empty]
  else with_bot.coe_le_coe.1 (le_trans (card_roots h)
    (by rw [hn, pow_zero, ← @C_1 α _, ← is_ring_hom.map_sub (@C α _ _)];
      exact degree_C_le))
else by rw [← with_bot.coe_le_coe, ← degree_X_pow_sub_C (nat.pos_of_ne_zero hn) a];
  exact card_roots (X_pow_sub_C_ne_zero (nat.pos_of_ne_zero hn) a)

end integral_domain

section field
variables [field α] {p q : polynomial α}
instance : vector_space α (polynomial α) :=
{ ..finsupp.to_module α }

lemma monic_mul_leading_coeff_inv (h : p ≠ 0) :
  monic (p * C (leading_coeff p)⁻¹) :=
by rw [monic, leading_coeff_mul, leading_coeff_C,
  mul_inv_cancel (show leading_coeff p ≠ 0, from mt leading_coeff_eq_zero.1 h)]

lemma degree_mul_leading_coeff_inv (h : p ≠ 0) :
  degree (p * C (leading_coeff p)⁻¹) = degree p :=
have h₁ : (leading_coeff p)⁻¹ ≠ 0 :=
  inv_ne_zero (mt leading_coeff_eq_zero.1 h),
by rw [degree_mul_eq, degree_C h₁, add_zero]

def div (p q : polynomial α) :=
C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹))

def mod (p q : polynomial α) :=
p %ₘ (q * C (leading_coeff q)⁻¹)

private lemma quotient_mul_add_remainder_eq_aux (p q : polynomial α) :
  q * div p q + mod p q = p :=
if h : q = 0 then by simp only [h, zero_mul, mod, mod_by_monic_zero, zero_add]
else begin
  conv {to_rhs, rw ← mod_by_monic_add_div p (monic_mul_leading_coeff_inv h)},
  rw [div, mod, add_comm, mul_assoc]
end

private lemma remainder_lt_aux (p : polynomial α) (hq : q ≠ 0) :
  degree (mod p q) < degree q :=
degree_mul_leading_coeff_inv hq ▸
  degree_mod_by_monic_lt p (monic_mul_leading_coeff_inv hq)
    (mul_ne_zero hq (mt leading_coeff_eq_zero.2 (by rw leading_coeff_C;
      exact inv_ne_zero (mt leading_coeff_eq_zero.1 hq))))

instance : has_div (polynomial α) := ⟨div⟩

instance : has_mod (polynomial α) := ⟨mod⟩

lemma div_def : p / q = C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹)) := rfl

lemma mod_def : p % q = p %ₘ (q * C (leading_coeff q)⁻¹) := rfl

lemma mod_by_monic_eq_mod (p : polynomial α) (hq : monic q) : p %ₘ q = p % q :=
show p %ₘ q = p %ₘ (q * C (leading_coeff q)⁻¹), by simp only [monic.def.1 hq, inv_one, mul_one, C_1]

lemma div_by_monic_eq_div (p : polynomial α) (hq : monic q) : p /ₘ q = p / q :=
show p /ₘ q = C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹)),
by simp only [monic.def.1 hq, inv_one, C_1, one_mul, mul_one]

lemma mod_X_sub_C_eq_C_eval (p : polynomial α) (a : α) : p % (X - C a) = C (p.eval a) :=
mod_by_monic_eq_mod p (monic_X_sub_C a) ▸ mod_by_monic_X_sub_C_eq_C_eval _ _

lemma mul_div_eq_iff_is_root : (X - C a) * (p / (X - C a)) = p ↔ is_root p a :=
div_by_monic_eq_div p (monic_X_sub_C a) ▸ mul_div_by_monic_eq_iff_is_root

instance : euclidean_domain (polynomial α) :=
{ quotient := (/),
  remainder := (%),
  r := _,
  r_well_founded := degree_lt_wf,
  quotient_mul_add_remainder_eq := quotient_mul_add_remainder_eq_aux,
  remainder_lt := λ p q hq, remainder_lt_aux _ hq,
  mul_left_not_lt := λ p q hq, not_lt_of_ge (degree_le_mul_left _ hq) }

lemma mod_eq_self_iff (hq0 : q ≠ 0) : p % q = p ↔ degree p < degree q :=
⟨λ h, h ▸ euclidean_domain.mod_lt _ hq0,
λ h, have ¬degree (q * C (leading_coeff q)⁻¹) ≤ degree p :=
  not_le_of_gt $ by rwa degree_mul_leading_coeff_inv hq0,
begin
  rw [mod_def, mod_by_monic, dif_pos (monic_mul_leading_coeff_inv hq0)],
  unfold div_mod_by_monic_aux,
  simp only [this, false_and, if_false]
end⟩

lemma div_eq_zero_iff (hq0 : q ≠ 0) : p / q = 0 ↔ degree p < degree q :=
⟨λ h, by have := euclidean_domain.div_add_mod p q;
  rwa [h, mul_zero, zero_add, mod_eq_self_iff hq0] at this,
λ h, have hlt : degree p < degree (q * C (leading_coeff q)⁻¹),
    by rwa degree_mul_leading_coeff_inv hq0,
  have hm : monic (q * C (leading_coeff q)⁻¹) := monic_mul_leading_coeff_inv hq0,
  by rw [div_def, (div_by_monic_eq_zero_iff hm (ne_zero_of_monic hm)).2 hlt, mul_zero]⟩

lemma degree_add_div (hq0 : q ≠ 0) (hpq : degree q ≤ degree p) :
  degree q + degree (p / q) = degree p :=
have degree (p % q) < degree (q * (p / q)) :=
  calc degree (p % q) < degree q : euclidean_domain.mod_lt _ hq0
  ... ≤ _ : degree_le_mul_left _ (mt (div_eq_zero_iff hq0).1 (not_lt_of_ge hpq)),
by conv {to_rhs, rw [← euclidean_domain.div_add_mod p q, add_comm,
    degree_add_eq_of_degree_lt this, degree_mul_eq]}

end field

section derivative
variables [comm_semiring α] {β : Type*}

/-- `derivative p` formal derivative of the polynomial `p` -/
def derivative (p : polynomial α) : polynomial α := p.sum (λn a, C (a * n) * X^(n - 1))

lemma derivative_apply (p : polynomial α) (n : ℕ) : (derivative p) n = p (n + 1) * (n + 1) :=
begin
  rw [derivative],
  simp only [finsupp.sum, X_pow_apply, sum_apply, C_mul_apply],
  rw [finset.sum_eq_single (n + 1)],
  { rw [if_pos (nat.add_sub_cancel _ _), mul_one, nat.cast_add, nat.cast_one] },
  { assume b, cases b,
    { intros, rw [nat.cast_zero, mul_zero, zero_mul] },
    { intros _ H, rw [nat.succ_sub_one b, if_neg (mt (congr_arg nat.succ) H), mul_zero] } },
  { intro H, rw [by_contradiction (mt (mem_support_iff _ _).2 H), zero_mul, zero_mul] }
end

@[simp] lemma derivative_zero : derivative (0 : polynomial α) = 0 :=
finsupp.sum_zero_index

lemma derivative_monomial (a : α) (n : ℕ) : derivative (C a * X ^ n) = C (a * n) * X^(n - 1) :=
by rw [← single_eq_C_mul_X, ← single_eq_C_mul_X, derivative, sum_single_index, single_eq_C_mul_X];
  simp only [zero_mul, C_0]; refl

@[simp] lemma derivative_C {a : α} : derivative (C a) = 0 :=
suffices derivative (C a * X^0) = C (a * 0:α) * X ^ 0,
  by simpa only [mul_one, zero_mul, C_0, mul_zero, pow_zero],
derivative_monomial a 0

@[simp] lemma derivative_X : derivative (X : polynomial α) = 1 :=
suffices derivative (C (1:α) * X^1) = C (1 * (1:ℕ)) * X ^ 0,
  by simpa only [mul_one, one_mul, C_1, pow_one, nat.cast_one, pow_zero],
derivative_monomial 1 1

@[simp] lemma derivative_one : derivative (1 : polynomial α) = 0 :=
derivative_C

@[simp] lemma derivative_add {f g : polynomial α} :
  derivative (f + g) = derivative f + derivative g :=
by refine finsupp.sum_add_index _ _; intros;
simp only [add_mul, zero_mul, C_0, C_add, C_mul]

@[simp] lemma derivative_sum {s : finset β} {f : β → polynomial α} :
  derivative (s.sum f) = s.sum (λb, derivative (f b)) :=
begin
  apply (finset.sum_hom derivative _ _).symm,
  exact derivative_zero,
  exact assume x y, derivative_add
end

@[simp] lemma derivative_mul {f g : polynomial α} :
  derivative (f * g) = derivative f * g + f * derivative g :=
calc derivative (f * g) = f.sum (λn a, g.sum (λm b, C ((a * b) * (n + m : ℕ)) * X^((n + m) - 1))) :
  begin
    transitivity, exact derivative_sum,
    transitivity, { apply finset.sum_congr rfl, assume x hx, exact derivative_sum },
    apply finset.sum_congr rfl, assume n hn, apply finset.sum_congr rfl, assume m hm,
    transitivity,
    { apply congr_arg, exact single_eq_C_mul_X },
    exact derivative_monomial _ _
  end
  ... = f.sum (λn a, g.sum (λm b,
      (C (a * n) * X^(n - 1)) * (C b * X^m) + (C a * X^n) * (C (b * m) * X^(m - 1)))) :
    sum_congr rfl $ assume n hn, sum_congr rfl $ assume m hm,
      by simp only [nat.cast_add, mul_add, add_mul, C_add, C_mul, mul_assoc, mul_left_comm];
      cases n; simp only [nat.cast_zero, C_0, nat.succ_sub_succ, zero_mul, mul_zero,
        zero_add, nat.sub_zero, pow_zero, pow_add, one_mul, mul_one];
      cases m; simp only [nat.cast_zero, C_0, nat.succ_sub_succ, zero_mul, mul_zero,
        zero_add, nat.sub_zero, pow_zero, pow_add, one_mul, mul_one];
      simp only [pow_succ, mul_comm, mul_left_comm]
  ... = derivative f * g + f * derivative g :
    begin
      conv {
        to_rhs,
        congr,
        { rw [← sum_C_mul_X_eq g] },
        { rw [← sum_C_mul_X_eq f] },
      },
      unfold derivative finsupp.sum,
      simp only [sum_add_distrib, finset.mul_sum, finset.sum_mul]
    end

lemma derivative_eval (p : polynomial α) (x : α) : p.derivative.eval x = p.sum (λ n a, (a * n)*x^(n-1)) :=
by simp [derivative, eval_sum, eval_pow]

end derivative

section domain
variables [integral_domain α]

lemma mem_support_derivative [char_zero α] (p : polynomial α) (n : ℕ) :
  n ∈ (derivative p).support ↔ n + 1 ∈ p.support :=
suffices (¬(p (n + 1) = 0 ∨ ((n + 1:ℕ) : α) = 0)) ↔ p (n + 1) ≠ 0,
  by simpa only [derivative_apply, mem_support_iff, ne.def, mul_eq_zero],
by rw [nat.cast_eq_zero]; simp only [nat.succ_ne_zero, or_false]

@[simp] lemma degree_derivative_eq [char_zero α] (p : polynomial α) (hp : 0 < nat_degree p) :
  degree (derivative p) = (nat_degree p - 1 : ℕ) :=
le_antisymm
  (le_trans (degree_sum_le _ _) $ sup_le $ assume n hn,
    have n ≤ nat_degree p,
    begin
      rw [← with_bot.coe_le_coe, ← degree_eq_nat_degree],
      { refine le_degree_of_ne_zero _, simpa only [mem_support_iff] using hn },
      { assume h, simpa only [h, support_zero] using hn }
    end,
    le_trans (degree_monomial_le _ _) $ with_bot.coe_le_coe.2 $ nat.sub_le_sub_right this _)
  begin
    refine le_sup _,
    rw [mem_support_derivative, nat.sub_add_cancel, mem_support_iff],
    { show ¬ leading_coeff p = 0,
      rw [leading_coeff_eq_zero],
      assume h, rw [h, nat_degree_zero] at hp,
      exact lt_irrefl 0 (lt_of_le_of_lt (zero_le _) hp), },
    exact hp
  end

end domain

section identities

/- @TODO: pow_add_expansion and pow_sub_pow_factor are not specific to polynomials.
  These belong somewhere else. But not in group_power because they depend on tactic.ring -/

def pow_add_expansion {α : Type*} [comm_semiring α] (x y : α) : ∀ (n : ℕ),
  {k // (x + y)^n = x^n + n*x^(n-1)*y + k * y^2}
| 0 := ⟨0, by simp⟩
| 1 := ⟨0, by simp⟩
| (n+2) :=
  begin
    cases pow_add_expansion (n+1) with z hz,
    rw [_root_.pow_succ, hz],
    existsi (x*z + (n+1)*x^n+z*y),
    simp [_root_.pow_succ],
    ring -- expensive!
  end

variable [comm_ring α]

private def poly_binom_aux1 (x y : α) (e : ℕ) (a : α) :
  {k : α // a * (x + y)^e = a * (x^e + e*x^(e-1)*y + k*y^2)} :=
begin
  existsi (pow_add_expansion x y e).val,
  congr,
  apply (pow_add_expansion _ _ _).property
end

private lemma poly_binom_aux2 (f : polynomial α) (x y : α) :
  f.eval (x + y) = f.sum (λ e a, a * (x^e + e*x^(e-1)*y + (poly_binom_aux1 x y e a).val*y^2)) :=
begin
  unfold eval eval₂, congr, ext,
  apply (poly_binom_aux1 x y _ _).property
end

private lemma poly_binom_aux3 (f : polynomial α) (x y : α) : f.eval (x + y) =
  f.sum (λ e a, a * x^e) +
  f.sum (λ e a, (a * e * x^(e-1)) * y) +
  f.sum (λ e a, (a *(poly_binom_aux1 x y e a).val)*y^2) :=
by rw poly_binom_aux2; simp [left_distrib, finsupp.sum_add, mul_assoc]

def binom_expansion (f : polynomial α) (x y : α) :
  {k : α // f.eval (x + y) = f.eval x + (f.derivative.eval x) * y + k * y^2} :=
begin
  existsi f.sum (λ e a, a *((poly_binom_aux1 x y e a).val)),
  rw poly_binom_aux3,
  congr,
  { rw derivative_eval, symmetry,
    apply finsupp.sum_mul },
  { symmetry, apply finsupp.sum_mul }
end

def pow_sub_pow_factor (x y : α) : Π {i : ℕ},{z : α // x^i - y^i = z*(x - y)}
| 0 := ⟨0, by simp⟩ --sorry --false.elim $ not_lt_of_ge h zero_lt_one
| 1 := ⟨1, by simp⟩
| (k+2) :=
  begin
    cases pow_sub_pow_factor with z hz,
    existsi z*x + y^(k+1),
    rw [_root_.pow_succ x, _root_.pow_succ y, ←sub_add_sub_cancel (x*x^(k+1)) (x*y^(k+1)),
        ←mul_sub x, hz],
    simp only [_root_.pow_succ],
    ring
  end

def eval_sub_factor (f : polynomial α) (x y : α) :
  {z : α // f.eval x - f.eval y = z*(x - y)} :=
begin
  existsi f.sum (λ a b, b * (pow_sub_pow_factor x y).val),
  unfold eval eval₂,
  rw [←finsupp.sum_sub],
  have : finsupp.sum f (λ (a : ℕ) (b : α), b * (pow_sub_pow_factor x y).val) * (x - y) =
    finsupp.sum f (λ (a : ℕ) (b : α), b * (pow_sub_pow_factor x y).val * (x - y)),
  { apply finsupp.sum_mul },
  rw this,
  congr, ext e a,
  rw [mul_assoc, ←(pow_sub_pow_factor x y).property],
  simp [left_distrib]
end

end identities

end polynomial
