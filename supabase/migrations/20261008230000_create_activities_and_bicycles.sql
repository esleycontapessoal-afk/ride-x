create table public.activities (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
    name text not null,
    activity_type text not null default 'cycling',
    status text not null default 'completed',
    started_at timestamptz not null default now(),
    ended_at timestamptz default now(),
    distance_km numeric(7, 2) not null default 0,
    elevation_m integer not null default 0,
    notes text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint activities_name_length check (char_length(trim(name)) between 1 and 120),
    constraint activities_type check (activity_type in ('cycling', 'gravel', 'mountain_biking', 'road')),
    constraint activities_status check (status in ('in_progress', 'completed')),
    constraint activities_distance_range check (distance_km between 0 and 2000),
    constraint activities_elevation_range check (elevation_m between 0 and 30000),
    constraint activities_notes_length check (char_length(notes) <= 2000),
    constraint activities_time_order check (ended_at is null or ended_at >= started_at),
    constraint activities_status_end_time check (
        (status = 'in_progress' and ended_at is null)
        or (status = 'completed' and ended_at is not null)
    )
);

create table public.bicycles (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
    name text not null,
    brand text not null default '',
    model text not null default '',
    category text not null default 'gravel',
    model_year integer,
    odometer_km numeric(9, 2) not null default 0,
    notes text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint bicycles_name_length check (char_length(trim(name)) between 1 and 120),
    constraint bicycles_brand_length check (char_length(brand) <= 80),
    constraint bicycles_model_length check (char_length(model) <= 120),
    constraint bicycles_category check (category in ('gravel', 'mountain', 'road', 'urban', 'other')),
    constraint bicycles_year_range check (model_year is null or model_year between 1885 and 2100),
    constraint bicycles_odometer_range check (odometer_km between 0 and 1000000),
    constraint bicycles_notes_length check (char_length(notes) <= 2000)
);

create index activities_user_started_at_idx
    on public.activities (user_id, started_at desc);
create unique index activities_one_in_progress_per_user_idx
    on public.activities (user_id)
    where status = 'in_progress';
create index bicycles_user_created_at_idx
    on public.bicycles (user_id, created_at desc);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;

create trigger activities_set_updated_at
    before update on public.activities
    for each row execute function public.set_updated_at();
create trigger bicycles_set_updated_at
    before update on public.bicycles
    for each row execute function public.set_updated_at();

alter table public.activities enable row level security;
alter table public.bicycles enable row level security;

create policy "Users can read their own activities"
    on public.activities for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "Users can create their own activities"
    on public.activities for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy "Users can update their own activities"
    on public.activities for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
create policy "Users can delete their own activities"
    on public.activities for delete to authenticated
    using ((select auth.uid()) = user_id);

create policy "Users can read their own bicycles"
    on public.bicycles for select to authenticated
    using ((select auth.uid()) = user_id);
create policy "Users can create their own bicycles"
    on public.bicycles for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy "Users can update their own bicycles"
    on public.bicycles for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
create policy "Users can delete their own bicycles"
    on public.bicycles for delete to authenticated
    using ((select auth.uid()) = user_id);

revoke all on public.activities, public.bicycles from anon;
grant select, insert, update, delete on public.activities, public.bicycles to authenticated;
