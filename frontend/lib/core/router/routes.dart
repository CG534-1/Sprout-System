class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const resetPassword = '/reset-password';
  static const today = '/today';
  static const myCare = '/my-care';
  static const profile = '/profile';
  static const updateDetails = '/profile/details';
  static const plantDetails = '/plants/:id';
  static const petDetails = '/pets/:id';
  static const addPlant = '/add-plant';
  static const addPet = '/add-pet';
  static const history = '/history';
  static const schedule = '/care-schedule';
  static const careDetails = '/care-details';

  static String plant(String id) => '/plants/$id';

  static String pet(String id) => '/pets/$id';
}
