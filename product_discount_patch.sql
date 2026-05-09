-- PATCH TO SUPPORT DYNAMIC DISCOUNTS IN SHARECO
-- Run this script in your Supabase SQL Editor to update your tables and enable discount rendering on the mobile app.

-- 1. Add 'original_price' column to 'products' table
alter table public.products 
add column if_not_exists original_price numeric(15,2) default null;

-- 2. Add 'original_price' column to 'product_variants' table
alter table public.product_variants 
add column if_not_exists original_price numeric(15,2) default null;

-- 3. Seed some sample discount prices for current seed products
-- Apple: Samsung Galaxy Buds FE (ID: 44444444-4444-4444-8444-444444444444)
-- Price is 1.590.000, set original price to 1.890.000 (~16% off)
update public.products 
set original_price = 1890000 
where id = '44444444-4444-4444-8444-444444444444';

-- Samsung: Galaxy S24 Ultra (ID: 33333333-3333-4333-8333-333333333333)
-- Price is 25.990.000, set original price to 29.990.000 (~13% off)
update public.products 
set original_price = 29990000 
where id = '33333333-3333-4333-8333-333333333333';

-- Zara: Áo Thun Cotton Zara Oversize Unisex (ID: 55555555-5555-4555-8555-555555555555)
-- Price is 350.000, set original price to 490.000 (~29% off)
update public.products 
set original_price = 490000 
where id = '55555555-5555-4555-8555-555555555555';
