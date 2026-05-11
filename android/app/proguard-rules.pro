# flutter_stripe references optional Stripe push-provisioning APIs; those classes
# are not on the classpath when push provisioning is unused. R8 otherwise fails release.
-dontwarn com.stripe.android.pushProvisioning.**
