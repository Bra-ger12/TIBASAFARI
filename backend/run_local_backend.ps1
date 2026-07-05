$ErrorActionPreference = 'Stop'

python manage.py migrate
python manage.py seed_rbac
python manage.py shell -c "from apps.accounts.models import User; from apps.drivers.models import DriverProfile; from apps.rbac.models import Role, UserRole; user, _ = User.objects.update_or_create(email='driver@example.com', defaults={'full_name':'Demo Driver','phone_number':'+255700000001','phone':'+255700000001','status':User.Status.ACTIVE,'is_active':True}); user.set_password('StrongPass123'); user.save(); role = Role.objects.get(code='DRIVER'); UserRole.objects.get_or_create(user=user, role=role); DriverProfile.objects.get_or_create(user=user, defaults={'license_number':'DRV-LOCAL-001'}); print('Demo driver ready: driver@example.com / StrongPass123')"
python manage.py runserver 127.0.0.1:8000 --noreload
