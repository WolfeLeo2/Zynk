-- Fix recursive RLS evaluation causing stack depth overflow on tenant-scoped writes.
-- current_tenant_id() is referenced by many table policies and must not evaluate
-- profiles RLS as an invoker function.

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.tenant_id
  FROM public.profiles p
  WHERE p.user_id = (SELECT auth.uid())
  LIMIT 1;
$$;