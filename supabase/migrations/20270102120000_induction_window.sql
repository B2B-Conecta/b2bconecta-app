create table b2b_private.induction_windows (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  started_at timestamptz not null default statement_timestamp()
);

alter table b2b_private.induction_windows enable row level security;
revoke all on b2b_private.induction_windows from public, anon, authenticated;

create function public.open_my_induction_window()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_ends_at timestamptz;
begin
  if not exists (
    select 1
    from public.profiles
    where id = v_user_id
      and role in ('aliado', 'importador')
      and account_access_status = 'active'
      and deactivated_at is null
  ) then
    return null;
  end if;

  insert into b2b_private.induction_windows (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select started_at + interval '48 hours'
  into v_ends_at
  from b2b_private.induction_windows
  where user_id = v_user_id;

  return v_ends_at;
end;
$$;

revoke all on function public.open_my_induction_window() from public, anon;
grant execute on function public.open_my_induction_window() to authenticated;
