-- The home invoker RPC needs namespace USAGE to reach its existing,
-- explicitly granted private ranking function. This grants no table access.
-- checkout_attempts remains protected by table ACLs and deny-by-default RLS.
grant usage on schema b2b_private to authenticated;
