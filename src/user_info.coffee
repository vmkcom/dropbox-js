# Information about a Dropbox user.
class DropboxUserInfo
  # Creates a UserInfo instance from a raw API response.
  #
  # @param {?Object} userInfo the result of parsing a JSON API response that
  #     describes a user
  # @return {Dropbox.UserInfo} a UserInfo instance wrapping the given API
  #     response; parameters that aren't parsed JSON objects are returned as
  #     the are
  @parse: (userInfo) ->
    if userInfo and typeof userInfo is 'object'
      new DropboxUserInfo userInfo
    else
      userInfo

  # @return {String} the user's name, in a form that is fit for display
  name: undefined

  # @return {?String} the user's email; this is not in the official API
  #     documentation, so it might not be supported
  email: undefined

  # @return {?String} two-letter country code, or null if unavailable
  countryCode: undefined

  # @return {String} unique ID for the user; this ID matches the unique ID
  #     returned by the authentication process
  uid: undefined

  # @return {String}
  referralUrl: undefined

  # @return {Number} the maximum amount of bytes that the user can store
  quota: undefined

  # @return {Number} the number of bytes taken up by the user's data
  usedQuota: undefined

  # @return {Number} the number of bytes taken up by the user's data that is
  #     not shared with other users
  privateBytes: undefined

  # @return {Number} the number of bytes taken up by the user's data that is
  #     shared with other users
  sharedBytes: undefined

  # Creates a UserInfo instance from a raw API response.
  #
  # @private
  # This constructor is used by Dropbox.UserInfo.parse, and should not be
  # called directly.
  #
  # @param {?Object} userInfo the result of parsing a JSON API response that
  #     describes a user
  constructor: (userInfo) ->
    @name = userInfo.display_name
    @email = userInfo.email
    @countryCode = userInfo.country or null
    @uid = userInfo.uid.toString()
    @referralUrl = userInfo.referral_link
    @quota = userInfo.quota_info.quota
    @privateBytes = userInfo.quota_info.normal or 0
    @sharedBytes = userInfo.quota_info.shared or 0
    @usedQuota = @privateBytes + @sharedBytes

