Mikuia.Events.on 'message', (from, to, message) ->
	if message == '!lukanya'
		Mikuia.Chat.say to, Mikuia.Settings.pluginGet('base', 'aboutMessage')