alter table public.activities
    drop constraint activities_status,
    drop constraint activities_status_end_time;

alter table public.activities
    add column tracking_mode text not null default 'manual',
    add column paused_at timestamptz,
    add column paused_seconds integer not null default 0,
    add constraint activities_status check (status in ('in_progress', 'paused', 'completed')),
    add constraint activities_tracking_mode check (tracking_mode in ('manual', 'gps', 'gpx')),
    add constraint activities_status_end_time check (
        (status in ('in_progress', 'paused') and ended_at is null)
        or (status = 'completed' and ended_at is not null)
    ),
    add constraint activities_pause_state check (
        (status = 'paused' and paused_at is not null)
        or (status <> 'paused' and paused_at is null)
    ),
    add constraint activities_paused_seconds check (paused_seconds between 0 and 31536000);

drop index if exists public.activities_one_in_progress_per_user_idx;
create unique index activities_one_open_per_user_idx
    on public.activities (user_id)
    where tracking_mode = 'gps' and status in ('in_progress', 'paused');

create table public.activity_points (
    id bigint generated always as identity primary key,
    activity_id uuid not null references public.activities (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
    sequence integer not null,
    latitude double precision not null,
    longitude double precision not null,
    accuracy_m double precision,
    altitude_m double precision,
    recorded_at timestamptz,
    segment_start boolean not null default false,
    source text not null,
    created_at timestamptz not null default now(),
    constraint activity_points_sequence_positive check (sequence >= 0),
    constraint activity_points_latitude check (latitude between -90 and 90),
    constraint activity_points_longitude check (longitude between -180 and 180),
    constraint activity_points_accuracy check (accuracy_m is null or accuracy_m between 0 and 50),
    constraint activity_points_altitude check (altitude_m is null or altitude_m between -12000 and 100000),
    constraint activity_points_source check (source in ('gps', 'gpx')),
    constraint activity_points_activity_sequence unique (activity_id, sequence)
);

create index activity_points_user_activity_idx
    on public.activity_points (user_id, activity_id);

alter table public.activity_points enable row level security;

create policy "Users can read their own activity points"
    on public.activity_points for select to authenticated
    using (
        (select auth.uid()) = user_id
        and exists (
            select 1 from public.activities
            where activities.id = activity_points.activity_id
                and activities.user_id = (select auth.uid())
        )
    );
create policy "Users can add points to their own activities"
    on public.activity_points for insert to authenticated
    with check (
        (select auth.uid()) = user_id
        and exists (
            select 1 from public.activities
            where activities.id = activity_points.activity_id
                and activities.user_id = (select auth.uid())
                and (
                    (activities.tracking_mode = 'gps' and activities.status in ('in_progress', 'paused'))
                    or activities.tracking_mode = 'gpx'
                )
        )
    );

revoke all on public.activity_points from anon;
grant select, insert on public.activity_points to authenticated;
grant usage, select on sequence public.activity_points_id_seq to authenticated;
