fs = require 'fs'
gm = require 'gm'
request = require 'request'

class exports.Channel extends Mikuia.Model
	constructor: (name) ->
		@model = 'channel'
		@name = name.replace('#', '').toLowerCase()

	# Core functions, changing those often end up breaking half of the universe.

	exists: (callback) ->
		await @_exists '', defer err, data
		callback err, data

	getName: () ->
		return @name

	isBot: (callback) ->
		await Mikuia.Database.sismember 'mikuia:bots', @getName(), defer err, data
		callback err, data

	isLive: (callback) ->
		# This is bad D:
		await Mikuia.Database.sismember 'mikuia:streams', @getName(), defer err, data
		callback err, data

	isStreamer: (callback) ->
		await @_exists 'plugins', defer err, data
		callback err, data

	# Info & settings

	getAll: (callback) ->
		await @_hgetall '', defer err, data
		callback err, data

	getInfo: (field, callback) ->
		await @_hget '', field, defer err, data
		callback err, data

	getSetting: (plugin, field, callback) ->
		await @_hget 'plugin:' + plugin + ':settings', field, defer err, data
		if Mikuia.Plugin.getManifest(plugin)?.settings?.channel?[field]?
			setting = Mikuia.Plugin.getManifest(plugin).settings.channel[field]
			if !data? && setting.default?
				data = setting.default
			if setting.type == 'boolean'
				if data == 'true'
					data = true
				if data == 'false'
					data = false
		callback err, data

	getSettings: (plugin, callback) ->
		await @_hgetall 'plugin:' + plugin + ':settings', defer err, data
		callback err, data

	setInfo: (field, value, callback) ->
		await @_hset '', field, value, defer err, data
		if callback
			callback err, data

	setSetting: (plugin, field, value, callback) ->
		if value != ''
			await @_hset 'plugin:' + plugin + ':settings', field, value, defer err, data
		else
			await @_hdel 'plugin:' + plugin + ':settings', field, defer err, data
		callback err, data

	# Enabling & disabling, whatever.

	disable: (callback) ->
		await
			Mikuia.Database.srem 'mikuia:channels', @getName(), defer err, data
		callback err, data

	enable: (callback) ->
		await
			Mikuia.Database.sadd 'mikuia:channels', @getName(), defer err, data
		callback err, data

	isEnabled: (callback) ->
		await Mikuia.Database.sismember 'mikuia:channels', @getName(), defer err, data
		callback err, data

	# Commands

	addCommand: (command, handler, callback) ->
		await @_hset 'commands', command, handler, defer err, data
		callback err, data

	getCommand: (command, callback) ->
		await @_hget 'commands', command, defer err, data
		callback err, data

	getCommandSettings: (command, defaults, callback) ->
		await
			@_hgetall 'command:' + command, defer err, settings
			@getCommand command, defer commandError, handler

		if !settings?
			settings = {}

		if !commandError
			for settingName, setting of settings
				console.log settings[settingName]
				if settings[settingName] == 'true'
					settings[settingName] = true
				if settings[settingName] == 'false'
					settings[settingName] = false

			if Mikuia.Plugin.getHandler(handler)?.settings?
				for settingName, setting of Mikuia.Plugin.getHandler(handler).settings
					if defaults && !settings[settingName]?
						settings[settingName] = setting.default				

		callback err, settings

	getCommands: (callback) ->
		await @_hgetall 'commands', defer err, data
		callback err, data

	removeCommand: (command, callback) ->
		await @_hdel 'commands', command, defer err, data
		callback err, data

	setCommandSetting: (command, key, value, callback) ->
		if value != ''
			await @_hset 'command:' + command, key, value, defer err, data
		else
			await @_hdel 'command:' + command, key, defer err, data
		callback err, data

	# Plugins

	disablePlugin: (name, callback) ->
		await @_srem 'plugins', name, defer err, data
		callback err, data

	enablePlugin: (name, callback) ->
		await @_sadd 'plugins', name, defer err, data
		callback err, data

	getEnabledPlugins: (callback) ->
		await @_smembers 'plugins', defer err, data
		callback err, data

	isPluginEnabled: (name, callback) ->
		await @_sismember 'plugins', name, defer err, data
		callback err, data

	# "Convenience" functions that help get and set data...  or something.

	getBio: (callback) ->
		await @getInfo 'bio', defer err, data
		callback err, data

	getDisplayName: (callback) ->
		await
			@getInfo 'display_name', defer err, data
			@isSupporter defer err2, isSupporter
		if err || !data?
			callback false, @getName()
		else
			if !err2 && isSupporter
				callback err, '❤ ' + data
			else
				callback err, data

	getEmail: (callback) ->
		await @getInfo 'email', defer err, data
		callback err, data

	getLogo: (callback) ->
		await @getInfo 'logo', defer err, data
		if err || !data?
			callback false, 'http://static-cdn.jtvnw.net/jtv_user_pictures/xarth/404_user_150x150.png'
		else
			callback err, data

	getProfileBanner: (callback) ->
		await @getInfo 'profileBanner', defer err, data
		callback err, data

	setBio: (bio, callback) ->
		await @setInfo 'bio', bio, defer err, data
		callback err, data

	setDisplayName: (name, callback) ->
		await @setInfo 'display_name', name, defer err, data
		callback err, data

	setEmail: (email, callback) ->
		await @setInfo 'email', email, defer err, data
		callback err, data

	setLogo: (logo, callback) ->
		await @setInfo 'logo', logo, defer err, data
		callback err, data

	setProfileBanner: (profileBanner, callback) ->
		await @setInfo 'profileBanner', profileBanner, defer err, data
		callback err, data

	# Moderatoring (LOL)

	isModOf: (channel, callback) ->
		if channel == @getName()
			return true
		else
			moderators = Mikuia.Chat.mods channel
			if moderators? && @getName() in moderators
				return true
			else
				return false

	# :D

	updateAvatar: (callback) ->
		randomNumber = Math.floor(Math.random() * 10000000)
		await @getInfo 'logo', defer err, logo
		if !err && logo.indexOf('http://') > -1
			avatarFolder = 'web/public/img/avatars'
			fs.mkdir avatarFolder if not fs.existsSync avatarFolder
			path = avatarFolder + '/' + @getName() + '.jpg'
			r = request.get(logo).pipe fs.createWriteStream path
			r.on 'finish', ->
				gm(path).resize(64, 64).write(path, (err) ->
					callback err
				)
		else
			callback true
			
	# Levels

	addExperience: (channel, experience, activity, callback) =>
		await @isBot defer err, isBot

		if !isBot
			await @getLevel channel, defer err, level
			if activity < 1 || !activity? || isNaN activity
				experience = 0

			otherChannel = new Mikuia.Models.Channel channel
			await otherChannel.getSetting 'base', 'disableLevels', defer err, disableLevels

			if !disableLevels
				await @_hincrby 'experience', channel, experience, defer err, data
				await @getLevel channel, defer err, newLevel

				await @updateTotalLevel defer whatever

				await
					otherChannel.getSetting 'base', 'announceLevels', defer err, announceLevels
					otherChannel.getSetting 'base', 'announceLimit', defer err2, announceLimit
				if !err && announceLevels && newLevel > level
					if !err2 && newLevel % announceLimit == 0 && activity > 0
						await @getDisplayName defer err, displayName
						await otherChannel.getDisplayName defer err, otherName
						Mikuia.Chat.sayRaw channel, '.me > ' + displayName + ' just advanced to ' + otherName + ' Level ' + newLevel + '!'

		callback false

	getLevel: (channel, callback) =>
		await @getExperience channel, defer err, data
		if !err && data?
			callback false, Mikuia.Tools.getLevel(data)
		else
			callback false, 0

	getTotalLevel: (callback) =>
		await @getInfo 'level', defer err, data
		if err || !data?
			callback false, 0
		else
			callback false, data

	getExperience: (channel, callback) =>
		await @_hget 'experience', channel, defer err, data
		callback err, data

	getAllExperience: (callback) =>
		await @_hgetall 'experience', defer err, data

		sortable = []
		for channel, experience of data
			sortable.push [channel, experience]
		sortable.sort (a,b) ->
			return b[1] - a[1]

		callback err, sortable

	getTotalExperience: (callback) =>
		await @getInfo 'experience', defer err, data
		if err || !data?
			callback false, 0
		else
			callback false, data

	updateTotalLevel: (callback) =>
		totalExperience = 0

		await @getAllExperience defer err, experience
		for data in experience
			totalExperience += parseInt data[1]
			await Mikuia.Database.zadd 'levels:' + data[0] + ':experience', data[1], @getName(), defer err, whatever

		totalLevel = Mikuia.Tools.getLevel totalExperience

		await @setInfo 'level', totalLevel, defer whatever, whatever
		await @setInfo 'experience', totalExperience, defer whatever, whatever
		await Mikuia.Database.zadd 'mikuia:experience', totalExperience, @getName(), defer whatever, whatever
		await Mikuia.Database.zadd 'mikuia:levels', totalLevel, @getName(), defer whatever, whatever

		callback totalLevel

	# Donator / Supporter stuff

	getSupporterStart: (callback) =>
		await @getInfo 'supporterStart', defer err, data
		callback err, data

	getSupporterStatus: (callback) ->
		await Mikuia.Database.zscore 'mikuia:supporters', @getName(), defer err, data
		callback err, data

	isDonator: (callback) ->
		await Mikuia.Database.zscore 'mikuia:donators', @getName(), defer err, data
		if data? && data >= 10
			callback err, true
		else
			callback err, false
	
	isSupporter: (callback) ->
		await @getSupporterStatus defer err, data
		if data > (new Date()).getTime() / 1000
			callback err, true
		else
			callback err, false

	# Badges

	addBadge: (badgeId, callback) =>
		await @_sadd 'badges', badgeId, defer err, data
		await Mikuia.Database.sadd 'badge:' + badgeId + ':members', @getName(), defer err2, data2
		callback err, data

	getBadges: (callback) =>
		await @_smembers 'badges', defer err, data
		callback err, data

	getBadgesWithInfo: (callback) =>
		await @getBadges defer err, data
		
		badgeInfo = {}
		for badgeId in data
			Badge = new Mikuia.Models.Badge badgeId

			await Badge.getAll defer err, badgeInfo[badgeId]

		callback err, badgeInfo

	removeBadge: (badgeId, callback) =>
		await @_srem 'badges', badgeId, defer err, data
		await Mikuia.Database.srem 'badge:' + badgeId + ':members', @getName(), defer err2, data2
		callback err, data