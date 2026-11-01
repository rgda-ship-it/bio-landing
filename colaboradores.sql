-- =====================================================================
-- Bio · Registro de colaboradores (invitacion.html)
-- Ejecutar UNA vez en Supabase → SQL Editor. Se puede repetir sin error.
-- No modifica waitlist, encuesta ni track_event.
-- =====================================================================
create table if not exists public.collaborators (
    id          bigint generated always as identity primary key,
    name        text not null check (length(name) between 1 and 80),
    contact     text not null check (length(contact) between 5 and 120),  -- email o teléfono
    roles       text[] not null default '{}',
    groups_text text check (length(groups_text) <= 500),
    lang        text not null default 'es',
    created_at  timestamptz not null default now()
);
alter table public.collaborators enable row level security;   -- sin políticas: nadie lee desde el navegador

create or replace function public.join_collaborators(
    p_name text, p_contact text, p_roles text[], p_groups text default null,
    p_lang text default 'es', p_consent boolean default false, p_website text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
    allowed text[] := array['difusion','pruebas','ideas','tareas'];
    r text;
begin
    if p_website is not null and length(p_website) > 0 then          -- honeypot: responde OK sin guardar
        return json_build_object('ok', true);
    end if;
    if not coalesce(p_consent, false) then
        raise exception 'consent_required';
    end if;
    if p_roles is not null then
        foreach r in array p_roles loop
            if not (r = any(allowed)) then raise exception 'invalid_role'; end if;
        end loop;
    end if;
    if (select count(*) from collaborators where created_at > now() - interval '1 minute') > 20 then
        raise exception 'rate_limited';
    end if;
    insert into collaborators (name, contact, roles, groups_text, lang)
    values (trim(p_name), trim(p_contact), coalesce(p_roles, '{}'), nullif(trim(p_groups), ''), coalesce(p_lang, 'es'));
    return json_build_object('ok', true);
end $$;
grant execute on function public.join_collaborators(text, text, text[], text, text, boolean, text) to anon;

-- Para ver quién se ha apuntado (en el SQL Editor):
-- select created_at, name, contact, roles, groups_text from collaborators order by created_at desc;
