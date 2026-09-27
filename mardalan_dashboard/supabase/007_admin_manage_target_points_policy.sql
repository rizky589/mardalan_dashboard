drop policy if exists "targets admin insert" on public.target_points;
create policy "targets admin insert"
  on public.target_points
  for insert
  to authenticated
  with check (public.is_admin_kabkot());

drop policy if exists "targets admin update" on public.target_points;
create policy "targets admin update"
  on public.target_points
  for update
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "targets admin delete" on public.target_points;
create policy "targets admin delete"
  on public.target_points
  for delete
  to authenticated
  using (public.is_admin_kabkot());
