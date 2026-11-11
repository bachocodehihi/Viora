module.exports = {

  email: {
    otp: {
      subject: 'Viora verification code',
      title: 'Viora',
      message: 'Your verification code is:',
      expiry: 'This code expires in 1 minute. If you did not request it, you can ignore this email.',
    },
    welcome: {
      subject: 'Welcome to Viora!',
      title: 'Welcome to Viora',
      message: 'Congratulations on successfully registering your account! Start connecting, sharing, and chatting with friends today.',
      securityTip: 'If you did not create this account, please ignore this email or contact support.',
    },
    signIn: {
      subject: 'Viora Sign-in Notification',
      title: 'Sign-in Successful',
      message: 'Your Viora account was just signed in successfully.',
      timeLabel: 'Sign-in Time',
      securityTip: 'If this was not you, please change your password immediately to protect your account.',
    },
    resetPassword: {
      subject: 'Viora Password Reset Successful',
      title: 'Password Changed Successfully',
      message: 'Your Viora account password has been reset successfully. You can now log in using your new password.',
      securityTip: 'If you did not perform this change, please contact us immediately to secure your account.',
    },
  },

  auth: {
    loginSuccess: 'Login successful',
    logoutSuccess: 'Logout successful',
    signupSuccess: 'Sign up successful',
    invalidCredentials: 'Invalid email or password',
    emailAlreadyExists: 'Email is already registered',
    accountCreated: 'Account created successfully',
    passwordChanged: 'Password changed successfully',
    otpSent: 'OTP sent',
    otpVerified: 'OTP verified',
    otpExpired: 'OTP expired',
    otpInvalid: 'Incorrect OTP',
  },

  errors: {
    invalidEmail: 'Invalid email',
    invalidPassword: 'Password must be at least 6 characters',
    invalidUsername: 'Invalid username',
    requiredField: 'This field is required',
    serverError: 'Server error',
    notFound: 'Not found',
    unauthorized: 'Unauthorized',
    forbidden: 'Forbidden',
  },

  notifications: {
    newFollower: 'followed you',
    newLike: 'liked your post',
    newComment: 'commented on your post',
    friendRequest: 'sent you a friend request',
    friendAccepted: 'accepted your friend request',
  },

};
