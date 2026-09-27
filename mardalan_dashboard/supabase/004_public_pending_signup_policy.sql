drop policy if exists "profiles public insert pending signup" on public.profiles;
create policy "profiles public insert pending signup"
  on public.profiles
  for insert
  to anon
  with check (
    status = 'pending'
    and role in ('petugas', 'supervisor')
    and email is not null
    and officer_code is not null
    and full_name is not null
  );

drop policy if exists "profiles authenticated insert own pending signup" on public.profiles;
create policy "profiles authenticated insert own pending signup"
  on public.profiles
  for insert
  to authenticated
  with check (
    status = 'pending'
    and role in ('petugas', 'supervisor')
    and auth_user_id = auth.uid()
  );
