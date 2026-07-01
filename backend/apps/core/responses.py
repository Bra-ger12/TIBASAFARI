from rest_framework.response import Response


def success_response(data=None, message="OK", status=200):
    return Response(
        {
            "success": True,
            "message": message,
            "data": data or {},
        },
        status=status,
    )
