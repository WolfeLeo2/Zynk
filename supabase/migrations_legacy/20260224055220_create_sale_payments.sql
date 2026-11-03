create table public.sale_payments (
    id uuid default gen_random_uuid() primary key,
    sale_id uuid not null references public.sales(id) on delete cascade,
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    amount numeric(10, 2) not null,
    payment_method text not null,
    reference_number text,
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS
alter table public.sale_payments enable row level security;

create policy "Users can view payments for their tenant"
    on public.sale_payments for select
    using (tenant_id = (select tenant_id from profiles where id = auth.uid()));

create policy "Users can insert payments for their tenant"
    on public.sale_payments for insert
    with check (tenant_id = (select tenant_id from profiles where id = auth.uid()));

create policy "Users can update payments for their tenant"
    on public.sale_payments for update
    using (tenant_id = (select tenant_id from profiles where id = auth.uid()));

create policy "Users can delete payments for their tenant"
    on public.sale_payments for delete
    using (tenant_id = (select tenant_id from profiles where id = auth.uid()));

