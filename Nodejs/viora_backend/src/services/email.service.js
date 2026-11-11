const nodemailer = require('nodemailer');
const { getLocale } = require('../locales');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.Email_USER,
    pass: process.env.Email_PASS,
  },
});

const sendOTP = async (email, otp, language = 'en') => {
  if (!process.env.Email_USER || !process.env.Email_PASS) {
    throw new Error('Email service is not configured');
  }

  const locale = getLocale(language);
  const template = locale.email.otp;

  await transporter.sendMail({
    from: `"Viora" <${process.env.Email_USER}>`,
    to: email,
    subject: template.subject,
    text: `${template.message} ${otp}. ${template.expiry}`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; border: 1px solid #e5e7eb;">
        <img src="cid:viora_logo" alt="Viora Logo" style="width: 100px; height: 100px; object-fit: cover; border-radius: 50%; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />
        <h2 style="color: #111827; font-size: 24px; font-weight: 700; margin-bottom: 16px; margin-top: 0;">${template.title}</h2>
        <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 32px;">${template.message}</p>
        
        <div style="background-color: #eff6ff; padding: 22px 16px; border-radius: 14px; margin: 24px auto 30px auto; border: 2px dashed #3b82f6; max-width: 320px; text-align: center; -webkit-user-select: all; -moz-user-select: all; -ms-user-select: all; user-select: all;">
          <span style="font-size: 38px; font-weight: 800; letter-spacing: 12px; margin-right: -12px; color: #1d4ed8; font-family: 'Consolas', 'Courier New', monospace; display: inline-block; -webkit-user-select: all; user-select: all;">${otp}</span>
        </div>
        
        <div style="border-top: 1px solid #f3f4f6; padding-top: 24px;">
          <p style="color: #9ca3af; font-size: 13px; line-height: 1.5; margin: 0;">${template.expiry}</p>
        </div>
      </div>
    `,
    attachments: [
      {
        filename: 'logo.png',
        path: require('path').join(__dirname, '../logo.png'),
        cid: 'viora_logo'
      }
    ]
  });
};

const signUpSuccessful = async (email, language = 'en') => {
  if (!process.env.Email_USER || !process.env.Email_PASS) {
    return;
  }

  const locale = getLocale(language);
  const template = locale.email.welcome;

  await transporter.sendMail({
    from: `"Viora" <${process.env.Email_USER}>`,
    to: email,
    subject: template.subject,
    text: `${template.title}\n\n${template.message}`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; border: 1px solid #e5e7eb;">
        <img src="cid:viora_logo" alt="Viora Logo" style="width: 100px; height: 100px; object-fit: cover; border-radius: 50%; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />
        <h2 style="color: #111827; font-size: 24px; font-weight: 700; margin-bottom: 16px; margin-top: 0;">${template.title}</h2>
        <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 24px;">${template.message}</p>
        <div style="background-color: #f0fdf4; padding: 16px 20px; border-radius: 10px; margin: 20px auto; border: 1px solid #bbf7d0; max-width: 360px;">
          <p style="color: #166534; font-size: 15px; font-weight: 600; margin: 0;">🎉 ${email}</p>
        </div>
        <div style="border-top: 1px solid #f3f4f6; padding-top: 24px; margin-top: 24px;">
          <p style="color: #9ca3af; font-size: 13px; line-height: 1.5; margin: 0;">${template.securityTip}</p>
        </div>
      </div>
    `,
    attachments: [
      {
        filename: 'logo.png',
        path: require('path').join(__dirname, '../logo.png'),
        cid: 'viora_logo'
      }
    ]
  });
};

const signInSuccessful = async (email, language = 'en') => {
  if (!process.env.Email_USER || !process.env.Email_PASS) {
    return;
  }

  const locale = getLocale(language);
  const template = locale.email.signIn;
  const timeStr = new Date().toLocaleString(language === 'vi' ? 'vi-VN' : 'en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });

  await transporter.sendMail({
    from: `"Viora" <${process.env.Email_USER}>`,
    to: email,
    subject: template.subject,
    text: `${template.title}\n\n${template.message}\n${template.timeLabel}: ${timeStr}`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; border: 1px solid #e5e7eb;">
        <img src="cid:viora_logo" alt="Viora Logo" style="width: 100px; height: 100px; object-fit: cover; border-radius: 50%; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />
        <h2 style="color: #111827; font-size: 24px; font-weight: 700; margin-bottom: 16px; margin-top: 0;">${template.title}</h2>
        <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 24px;">${template.message}</p>
        <div style="background-color: #f8fafc; padding: 16px 20px; border-radius: 10px; margin: 20px auto; border: 1px solid #e2e8f0; max-width: 360px; text-align: left;">
          <p style="color: #475569; font-size: 14px; margin: 0 0 6px 0;"><strong>${template.timeLabel}:</strong> ${timeStr} (GMT+7)</p>
          <p style="color: #475569; font-size: 14px; margin: 0;"><strong>Email:</strong> ${email}</p>
        </div>
        <div style="border-top: 1px solid #f3f4f6; padding-top: 24px; margin-top: 24px;">
          <p style="color: #9ca3af; font-size: 13px; line-height: 1.5; margin: 0;">${template.securityTip}</p>
        </div>
      </div>
    `,
    attachments: [
      {
        filename: 'logo.png',
        path: require('path').join(__dirname, '../logo.png'),
        cid: 'viora_logo'
      }
    ]
  });
};

const changePasswordSuccessful = async (email, language = 'en') => {
  if (!process.env.Email_USER || !process.env.Email_PASS) {
    return;
  }

  const locale = getLocale(language);
  const template = locale.email.resetPassword;

  await transporter.sendMail({
    from: `"Viora" <${process.env.Email_USER}>`,
    to: email,
    subject: template.subject,
    text: `${template.title}\n\n${template.message}`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; border: 1px solid #e5e7eb;">
        <img src="cid:viora_logo" alt="Viora Logo" style="width: 100px; height: 100px; object-fit: cover; border-radius: 50%; margin-bottom: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />
        <h2 style="color: #111827; font-size: 24px; font-weight: 700; margin-bottom: 16px; margin-top: 0;">${template.title}</h2>
        <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 24px;">${template.message}</p>
        <div style="background-color: #f8fafc; padding: 16px 20px; border-radius: 10px; margin: 20px auto; border: 1px solid #e2e8f0; max-width: 360px; text-align: left;">
          <p style="color: #475569; font-size: 14px; margin: 0;"><strong>Email:</strong> ${email}</p>
        </div>
        <div style="border-top: 1px solid #f3f4f6; padding-top: 24px; margin-top: 24px;">
          <p style="color: #9ca3af; font-size: 13px; line-height: 1.5; margin: 0;">${template.securityTip}</p>
        </div>
      </div>
    `,
    attachments: [
      {
        filename: 'logo.png',
        path: require('path').join(__dirname, '../logo.png'),
        cid: 'viora_logo'
      }
    ]
  });
};

const signInNewDevice = async (email, language = 'en') => {};

const friendInvitation = async (email, language = 'en') => {};

const makeFriendSuccessfully = async (email, language = 'en') => {};

const yourAccountBanned = async (email, language = 'en') => {};

const joinGroupSuccessful = async (email, language = 'en') => {};

const newMemberJoinGroup = async (email, language = 'en') => {};

const newFollower = async (email, language = 'en') => {};

const commentYourPost = async (email, language = 'en') => {};

const likeYourPost = async (email, language = 'en') => {};

const commentYourStatus = async (email, language = 'en') => {};

const likeYourStatus = async (email, language = 'en') => {};

const likeYourComment = async (email, language = 'en') => {};

module.exports = { 
  sendOTP,
  signUpSuccessful,
  signInSuccessful,
  changePasswordSuccessful,
  signInNewDevice,
  friendInvitation,
  makeFriendSuccessfully,
  yourAccountBanned,
  joinGroupSuccessful,
  newMemberJoinGroup,
  newFollower,
  commentYourPost,
  likeYourPost,
  commentYourStatus,
  likeYourStatus,
  likeYourComment
};
