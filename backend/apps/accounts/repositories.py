from apps.accounts.models import User


class UserRepository:
    model = User

    def list(self):
        return self.model.objects.prefetch_related("role_assignments__role").all()

    def get_by_email(self, email: str):
        return self.model.objects.filter(email__iexact=email).first()

    def create(self, **data):
        password = data.pop("password")
        return self.model.objects.create_user(password=password, **data)
