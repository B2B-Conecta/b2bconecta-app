update auth.users
set email_confirmed_at = now()
where email = 'prueba@mail.com';