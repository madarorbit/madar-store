alter table public.profiles alter column email drop not null;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,email,full_name,phone,email_verified)
 values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',''),new.phone,new.email_confirmed_at is not null)
 on conflict(id) do update set
  email=coalesce(excluded.email,public.profiles.email),
  phone=coalesce(excluded.phone,public.profiles.phone),
  email_verified=excluded.email_verified;
 return new;
end;
$$;

revoke all on function public.handle_new_user() from public,anon,authenticated;
grant execute on function public.handle_new_user() to service_role;
