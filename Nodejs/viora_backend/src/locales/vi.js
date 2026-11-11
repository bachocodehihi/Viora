module.exports = {
  email: {
    otp: {
      subject: 'Mã xác thực Viora',
      title: 'Viora',
      message: 'Mã xác thực của bạn là:',
      expiry: 'Mã này sẽ hết hạn sau 1 phút. Nếu bạn không yêu cầu mã này, bạn có thể bỏ qua email này.',
    },
    welcome: {
      subject: 'Chào mừng bạn đến với Viora!',
      title: 'Chào mừng đến với Viora',
      message: 'Chúc mừng bạn đã đăng ký tài khoản thành công! Hãy bắt đầu kết nối, chia sẻ và trò chuyện cùng bạn bè ngay hôm nay.',
      securityTip: 'Nếu bạn không thực hiện đăng ký này, vui lòng bỏ qua hoặc liên hệ hỗ trợ.',
    },
    signIn: {
      subject: 'Thông báo đăng nhập tài khoản Viora',
      title: 'Đăng nhập thành công',
      message: 'Tài khoản Viora của bạn vừa được đăng nhập thành công.',
      timeLabel: 'Thời gian đăng nhập',
      securityTip: 'Nếu đây không phải là bạn, hãy đổi mật khẩu ngay lập tức để bảo vệ tài khoản của mình.',
    },
    resetPassword: {
      subject: 'Đặt lại mật khẩu Viora thành công',
      title: 'Mật khẩu đã được thay đổi',
      message: 'Mật khẩu tài khoản Viora của bạn đã được đặt lại thành công. Bây giờ bạn có thể đăng nhập bằng mật khẩu mới.',
      securityTip: 'Nếu bạn không thực hiện thay đổi này, hãy liên hệ ngay với chúng tôi để bảo vệ tài khoản.',
    },
  },

  auth: {
    loginSuccess: 'Đăng nhập thành công',
    logoutSuccess: 'Đăng xuất thành công',
    signupSuccess: 'Đăng ký thành công',
    invalidCredentials: 'Email hoặc mật khẩu không đúng',
    emailAlreadyExists: 'Email đã được đăng ký',
    accountCreated: 'Tài khoản đã được tạo thành công',
    passwordChanged: 'Mật khẩu đã được thay đổi',
    otpSent: 'Mã xác thực đã được gửi',
    otpVerified: 'Xác thực thành công',
    otpExpired: 'Mã xác thực đã hết hạn',
    otpInvalid: 'Mã xác thực không đúng',
  },

  errors: {
    invalidEmail: 'Email không hợp lệ',
    invalidPassword: 'Mật khẩu phải có ít nhất 6 ký tự',
    invalidUsername: 'Tên người dùng không hợp lệ',
    requiredField: 'Trường này là bắt buộc',
    serverError: 'Lỗi máy chủ',
    notFound: 'Không tìm thấy',
    unauthorized: 'Không có quyền truy cập',
    forbidden: 'Truy cập bị từ chối',
  },

  notifications: {
    newFollower: 'đã theo dõi bạn',
    newLike: 'đã thích bài viết của bạn',
    newComment: 'đã bình luận về bài viết của bạn',
    friendRequest: 'đã gửi lời mời kết bạn',
    friendAccepted: 'đã chấp nhận lời mời kết bạn',
  },

};
