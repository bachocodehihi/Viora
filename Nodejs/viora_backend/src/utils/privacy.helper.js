const filterAccountByPrivacy = (account, viewer = null) => {
  if (!account) return null;

  const accountObj = account.toObject ? account.toObject({ virtuals: true }) : { ...account };
  delete accountObj.password;

  if (viewer && viewer._id.toString() === accountObj._id.toString()) {
    return accountObj;
  }

  const isFriend = viewer && accountObj.friends?.some(
    f => f.toString() === viewer._id.toString()
  );

  const canView = (privacySetting) => {
    if (!privacySetting) return true;
    if (privacySetting === 'public') return true;
    if (privacySetting === 'friends' && isFriend) return true;
    if (privacySetting === 'private') return false;
    return false;
  };

  const privacy = accountObj.privacy || {};

  if (!canView(privacy.showPhone)) delete accountObj.phone;
  if (!canView(privacy.showEmail)) delete accountObj.email;
  if (!canView(privacy.showBirthday)) delete accountObj.birthday;
  if (!canView(privacy.showGender)) delete accountObj.gender;
  if (!canView(privacy.showAddress)) {
    delete accountObj.address;
    delete accountObj.nationId;
    delete accountObj.cityId;
    delete accountObj.wardId;
  }
  if (!canView(privacy.showJob)) delete accountObj.job;
  if (!canView(privacy.showNationality)) delete accountObj.nationality;

  if (!canView(privacy.friendList)) {
    delete accountObj.friends;
    delete accountObj.friendsCount;
  }

  delete accountObj.googleId;
  delete accountObj.blockedUsers;
  delete accountObj.isDeleted;
  delete accountObj.deleteAt;

  return accountObj;
};

module.exports = { filterAccountByPrivacy };
