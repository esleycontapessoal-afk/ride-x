create table public.profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    full_name text not null,
    handle text,
    age integer,
    height_cm integer,
    weight_kg numeric(5, 2),
    bio text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_full_name_length check (char_length(trim(full_name)) between 1 and 80),
    constraint profiles_handle_length check (handle is null or char_length(trim(handle)) between 1 and 30),
    constraint profiles_age_range check (age is null or age between 1 and 120),
    constraint profiles_height_range check (height_cm is null or height_cm between 80 and 250),
    constraint profiles_weight_range check (weight_kg is null or weight_kg between 20 and 350),
    constraint profiles_bio_length check (char_length(bio) <= 500)
);

create trigger profiles_set_updated_at
    before update on public.profiles
    for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "Users can read their own profile"
    on public.profiles for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "Users can create their own profile"
    on public.profiles for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy "Users can update their own profile"
    on public.profiles for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

revoke all on public.profiles from anon;
grant select, insert, update on public.profiles to authenticated;
