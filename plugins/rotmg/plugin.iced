cli = require 'cli-color'
request = require 'request'

userData = {}

checkRankUpdates = (stream, callback) =>
	console.log 'rotmg1'
	await Mikuia.Database.hget 'mikuia:stream:' + stream, 'game', defer err, game
	if err || !game? || game.indexOf('Realm of the Mad God') == -1
		callback err, null
	else
		console.log 'rotmg2'
		Channel = new Mikuia.Models.Channel stream
		await
			Channel.getDisplayName defer err, displayName
			Channel.isPluginEnabled 'rotmg', defer err2, enabled

		if !err && enabled
			console.log 'rotmg3'
			await
				Channel.getSetting 'rotmg', 'fameChanges', defer err, fameChanges
				Channel.getSetting 'rotmg', 'fameLimit', defer err2, fameLimit
				Channel.getSetting 'rotmg', 'name', defer err3, username

			if !err && fameChanges && username
				console.log 'rotmg4'
				request 'http://webhost.ischool.uw.edu/~joatwood/realmeye_api/0.3/?player=' + username, (error, response, body) =>
					if !error && response.statusCode == 200
						console.log 'rotmg5'
						try
							json = JSON.parse body
						catch error
							if error
								Mikuia.Log.error cli.redBright('RotMG') + ' / ' + cli.cyan(displayName) + ' / JSON parsing error: ' + error

						if json && !json.error?
							console.log 'rotmg6'
							if userData[json.player]?
								console.log 'rotmg7'
								diff = json.fame - userData[json.player].fame
								rank = json.fame_rank - userData[json.player].fame_rank

								if diff >= fameLimit
									Mikuia.Chat.say Channel.getName(), 'Fame: ' + json.fame + ' (gained ' + diff + ')'
								else if diff < 0
									Mikuia.Chat.say Channel.getName(), 'Fame: ' + json.fame + ' (lost ' + Math.abs(diff) + ')'

								if diff != 0 && Math.abs(diff) >= fameLimit
									if rank > 0
										Mikuia.Chat.say Channel.getName(), 'Fame Rank: #' + json.fame_rank + ' (' + rank + ' down' + ')'
									else if rank < 0
										Mikuia.Chat.say Channel.getName(), 'Fame Rank: #' + json.fame_rank + ' (' + Math.abs(rank) + ' up!)'
							console.log 'rotmg8'
							userData[json.player] =
								fame: json.fame
								fame_rank: json.fame_rank

					else
						Mikuia.Log.error cli.redBright('RotMG') + ' / ' + cli.cyan(displayName) + ' / Failed to get JSON.'


Mikuia.Events.on 'rotmg.rank', (data) =>
	Channel = new Mikuia.Models.Channel data.to
	await
		Channel.getDisplayName defer err, displayName
		Channel.isPluginEnabled 'rotmg', defer err2, enabled

	if !err2 && enabled

		tokens = data.tokens.slice 0
		tokens.splice 0, 1
		username = tokens.join ' '

		if username == ''
			await Channel.getSetting 'rotmg', 'name', defer err, username

		request 'http://webhost.ischool.uw.edu/~joatwood/realmeye_api/0.3/?player=' + username, (error, response, body) =>
			if !error && response.statusCode == 200
				try
					json = JSON.parse body
				catch error
					if error
						Mikuia.Log.error cli.redBright('RotMG') + ' / ' + cli.cyan(displayName) + ' / JSON parsing error: ' + error

				if json && !json.error?
					if json.fame > 0
						Mikuia.Chat.say Channel.getName(), 'Stats for ' + json.player + ': ★ ' + json.rank + ', ' + json.fame + ' Fame, rank #' + json.fame_rank + '.'
					else
						Mikuia.Chat.say Channel.getName(), 'Stats for ' + json.player + ': ★ ' + json.rank + ', ' + json.fame + ' Fame.'
				 
			else
				Mikuia.Log.error cli.redBright('RotMG') + ' / ' + cli.cyan(displayName) + ' / Failed to get JSON.'

setInterval () =>
	await Mikuia.Streams.getAll defer err, streams
	if !err && streams?
		for stream in streams
			await checkRankUpdates stream, defer err, status
, 15000