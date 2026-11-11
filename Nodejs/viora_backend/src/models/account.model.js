const mongoose = require('mongoose');

const accountSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, trim: true, lowercase: true },
  username: { type: String, required: true, trim: true },
  password: { type: String },
  birthday: { type: Date, required: true },
  gender: { type: String, enum: ['male', 'female', 'other'], required: true },
  avatar: { type: String, default: process.env.DEFAULT_AVATAR_URL || '' },
  coverImage: { type: String, default: '' },
  bio: { type: String, default: '', maxLength: 300 },
  note: { type: String, default: '', maxLength: 100 },
  noteExpiresAt: { type: Date, default: null },

  phone: { type: String, default: '', trim: true },
  address: { type: String, default: '' },
  homeTown: { type: String, default: '' },
  job: { type: String, default: '' },
  nationality: { type: String, default: '' },
  hobby: { type: String, default: '' },
  qrCode: { type: String, default: '' },

  nationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Nation', default: null },
  cityId: { type: mongoose.Schema.Types.ObjectId, ref: 'City', default: null },
  wardId: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward', default: null },

  homeTownNationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Nation', default: null },
  homeTownCityId: { type: mongoose.Schema.Types.ObjectId, ref: 'City', default: null },
  homeTownWardId: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward', default: null },

  placesLived: [{
    address: { type: String, default: '' },
    nationality: { type: String, default: '' },
    nationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Nation', default: null },
    cityId: { type: mongoose.Schema.Types.ObjectId, ref: 'City', default: null },
    wardId: { type: mongoose.Schema.Types.ObjectId, ref: 'Ward', default: null },
    createdAt: { type: Date, default: Date.now }
  }],

  friends: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  followers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  blockedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  blockedFriends: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  notInterestedPosts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],

  friendsCount: { type: Number, default: 0 },
  followersCount: { type: Number, default: 0 },
  followingCount: { type: Number, default: 0 },

  isPrivate: { type: Boolean, default: false },

  privacy: {
    isPrivate: { type: Boolean, default: false },
    profile: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    friendList: { type: String, enum: ['public', 'friends', 'private'], default: 'friends' },
    whoCanMessage: { type: String, enum: ['everyone', 'friends', 'nobody'], default: 'everyone' },
    whoCanFollow: { type: String, enum: ['everyone', 'friends'], default: 'everyone' },
    showActiveStatus: { type: Boolean, default: true },
    
    showPhone: { type: String, enum: ['public', 'friends', 'private'], default: 'private' },
    showEmail: { type: String, enum: ['public', 'friends', 'private'], default: 'friends' },
    showBirthday: { type: String, enum: ['public', 'friends', 'private'], default: 'friends' },
    showGender: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    showAddress: { type: String, enum: ['public', 'friends', 'private'], default: 'friends' },
    showHomeTown: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    showJob: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    showNationality: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    showHobby: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    showPlacesLived: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
    //showSchool: { type: String, enum: ['public', 'friends', 'private'], default: 'public' },
  },

  googleId: { type: String, default: null },

  role: { type: String, enum: ['user', 'admin', 'moderator'], default: 'user' },
  isVerified: { type: Boolean, default: false },
  twoFactorEnabled: { type: Boolean, default: false },
  isOnline: { type: Boolean, default: false },
  lastSeen: { type: Date, default: Date.now },

  currentDeviceId: { type: String, default: '' },
  currentDeviceName: { type: String, default: '' },

  fcmToken: { type: String, default: '' },
  fcmTokens: [{ type: String }],

  isDeleted: { type: Boolean, default: false },
  deleteAt: { type: Date, default: null },

  deletionRequested: { type: Boolean, default: false },
  deletionRequestedAt: { type: Date, default: null },
  deletionScheduledAt: { type: Date, default: null },
  deletionReason: { type: String, default: '' }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

accountSchema.index({ friends: 1 });

accountSchema.virtual('posts', {
  ref: 'Post',
  localField: '_id',
  foreignField: 'author'
});

const Account = mongoose.model('Account', accountSchema);
module.exports = Account;
