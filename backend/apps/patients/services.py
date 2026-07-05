from apps.patients.models import PatientProfile


class PatientService:
    def create_profile(self, *, user, **data):
        return PatientProfile.objects.create(user=user, **data)

    def update_profile(self, profile, **data):
        for field, value in data.items():
            setattr(profile, field, value)
        profile.save()
        return profile

