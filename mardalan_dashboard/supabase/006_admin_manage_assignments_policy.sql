drop policy if exists "assignments admin insert" on public.assignments;
create policy "assignments admin insert"
  on public.assignments
  for insert
  to authenticated
  with check (public.is_admin_kabkot());

drop policy if exists "assignments admin update" on public.assignments;
create policy "assignments admin update"
  on public.assignments
  for update
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "assignments admin delete" on public.assignments;
create policy "assignments admin delete"
  on public.assignments
  for delete
  to authenticated
  using (public.is_admin_kabkot());
