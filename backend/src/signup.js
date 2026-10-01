export function signupEmailTaken(user, profile) {
  if (!user) return false;
  const meta = user.user_metadata ?? {};
  const flag = (value) => value === true || value === 'true';
  if (flag(meta.password_set) || profile) return true;
  if (flag(meta.signup_pending)) return false;
  return true;
}
