# token bot

`token` is a chat bot for acknowledging and thanking peers. It can be used to award prizes to people who have helped others. It was built on the [Hubot][hubot] framework.

## Summary

The bot keeps track of acknowledgment given from one user to another. Each unit of acknowledgment is called a **token**. Everyone starts out with the same number of tokens. Users can `give` one token at a time to other users.

Users can also `revoke` a token. There are a couple reasons why someone may revoke a token. One may decide that the person was not helping as much as hoped. Or one may want to give that token to someone else who has been more helpful. 

Users can also ask the bot to show the `status` of a user, and they can ask for a `leaderboard` of who has received the most tokens. 

The administrator of the bot can "freeze" the giving and revoking of tokens using the environment variable `TOKENS_CAN_BE_TRANSFERRED`. Details on how to do that, and what the other environment variables are, are given in the section [Technical information](#technical-information).

The bot was developed for a randomized controlled trial on social networks and entrepreneurship called [The Adansonia Project][adansonia]. At the end of the experiment, each token is a lottery ticket for a prize. Thus, the `token` bot can create incentives for people to help one another.

[hubot]: http://hubot.github.com
[adansonia]: https://adansonia.net/

## Usage 

### Format of commands
The bot responds to commands in public channels that begin with its name `token`:
```
token <command>
```
You can also set an alias for the bot, as described in the [Configuration](#configuration) section. For example, if `/` is an alias for the bot's name `token`, then you can also write commands as
```
/<command>
```
Example of commands are given below.

(You can change whether the bot listens for commands in all public channels by changing an environment variable, as explained below [in the configuration section](#create-a-bot-user-in-Rocket.Chat).)

You can also enter commands in a direct message with `@token`, the bot. That way, other people don't need to see your command. When you enter a command in a direct message, you don't need to write `token` (nor an alias such as `/`) at the beginning of the command.

### Giving and revoking tokens 

Did `@UsainBolt` help you become a better sprinter? Then `/give` a token to `@UsainBolt` to thank him!
```
/give a token to @UsainBolt
```
The bot responds in the same channel with the message that looks like
```
@Charlie gave one token to @UsainBolt. @Charlie now has 1 token remaining to give to others.
```
You can also simply write `/give @UsainBolt` to give `@UsainBolt` a token.

Want to thank `@UsainBolt` *even more* for all the gold medals you're winning thanks to him? Then give him more tokens! You can give someone more than one token by using the above command multiple times.

Changed your mind? Or someone else has helped you even more and you've run out of tokens to give them? Then `/revoke` a token from `@UsainBolt`:
```
/revoke a token from @UsainBolt
```
The bot responds in that channel with the message 
```
@charlie revoked one token from @UsainBolt. @charlie now has 2 token remaining to give to others.
```
Alternatively, simply write `/revoke @UsainBolt`.

### Status

Want to check how many tokens you have left in your "pocket", how many you've given out (and to whom), and how many you've received (and from whom)? Then use the `/status` command: 
```
/status
```
The `@token` bot will then send you a direct message that looks like this:
```
@charlie has 2 tokens remaining to give to others. 
@charlie has given 3 tokens to the following people: @UsainBolt (2), @A.Einstein (1)
@charlie has 2 tokens from the following people: @UsainBolt (2)
```
(The response is a direct message because it contains mentions of many other users, and we don't want those users to be bothered by these responses.)

You can also use this command to check the status of any other user:
```
/status @A.Einstein
```
The reply from the `@token` bot will be a direct message that looks just like the example given above of a response to the command `/status`.

### Who still has tokens to give out?

Got time to spare and want to find people to help? Use the following command to see a list of all people who still tokens available to give to others:

```
/show users with tokens
```
(Alternatively, you can write `/who has tokens?`.) The `@token` bot then replies in a direct message with a list of who still has tokens to give out: 
```
The following users still have tokens to give. Try to help these users so that they thank you with a token!
@A.Einstein (4 tokens), @UsainBolt (3 tokens)
```

### Leaderboard 

Who has been given the most tokens? See who's on top with the `/leaderboard` command, which shows the top 10 users in descending order of the number of tokens received:
```
These 3 users have currently been thanked the most:
1. @UsainBolt (2 tokens) 
2. @charlie (2 tokens) 
3. @A.Einstein (1 token)
4. @A.Smith (1 token)
5. @Galileo (1 token)
```

Control how large the leaderboard is using the command `/show top 5 list` or `/show top eight`. The bot responds with a direct message that looks like:
```
These 3 users have currently been thanked the most:
1. @UsainBolt (2 tokens) 
2. @charlie (2 tokens) 
3. @A.Einstein (1 token) 
```

### Help - show a list of all commands

Enter the command `token help` to show a list of all commands.

## Technical information 

### Generation 

This bot was initially generated by [generator-hubot][generator-hubot] and configured to be
deployed on [Heroku][heroku].

[heroku]: http://www.heroku.com
[generator-hubot]: https://github.com/github/generator-hubot

### Adapters

This bot currently uses the [Rocket.Chat Hubot adapter][rocketchat-hubot]. 

[rocketchat-hubot]: https://github.com/RocketChat/hubot-rocketchat



### Running token Locally

Test the token bot locally by running 

    % bin/hubot

You'll see some start up output and a prompt:

    token> [Mon Jul 18 2016 12:10:53 GMT-0500 (CDT)] INFO hubot-redis-brain: Using default redis on localhost:6379
    token>

See a list of commands by typing `token help`.

    token> token help
    token give a token to @user_name - Gives a token to `@user_name`. The words 'token', 'a' and 'to' are optional.
    token help - Displays all of the help commands that token knows about.
    ...

## Configuration

### Environment variables 

The following environment variables can optionally be set: 

* `TOKEN_ALLOW_SELF` -- whether people can give tokens to themselves. If not set, the default is `false`.
* `TOKENS_CAN_BE_TRANSFERRED` -- whether tokens can be given and revoked. If not set, the default is `true`. Set this to false if you want to prevent people from giving and revoking tokens.
* `TOKENS_ENDOWED_TO_EACH_USER` -- the number of tokens that each user gets initially. If not set, the default is 5.
* `HUBOT_ALIAS` -- an alias that the bot will respond to when listening for commands. For example, set this variable to '/'.

Examples of how to set these are given below for the case of using Heroku to deploy the bot.

### Deploy on Heroku 

To use [Heroku][heroku] to deploy the bot, first follow [these instructions][heroku-hubot]. Then set the environment variables using the following commands in a terminal:
```
heroku config:set TOKEN_ALLOW_SELF=false
heroku config:set TOKENS_CAN_BE_TRANSFERRED=true
heroku config:set TOKENS_ENDOWED_TO_EACH_USER=5
heroku config:set HUBOT_HEROKU_KEEPALIVE_URL=<url-for-your-token-bot>
heroku config:set HUBOT_ALIAS=/
```

where `<url-for-your-token-bot>` is a URL such as `https://token-bot.herokuapp.com/`. If you later want to freeze the giving and revoking of tokens, then run 
```
heroku config:set TOKENS_CAN_BE_TRANSFERRED=true
```

#### Create a bot user in Rocket.Chat

First create a bot in your Rocket.Chat instance. The administrator can do this as follows: click on "Administration", then clicking on “+” button, and then choose “Bots” under the pull-down menu “Role”.

Then log into your Heroku account in a terminal and set the following environment variables:

* `heroku config:set ROCKETCHAT_URL="https://<your-rocket-chat-instance-name>.rocket.chat"`
* `heroku config:set ROCKETCHAT_ROOM="general"`
* `heroku config:set LISTEN_ON_ALL_PUBLIC=true`
* `heroku config:set ROCKETCHAT_USER=token`
* `heroku config:set ROCKETCHAT_PASSWORD=<your-password-for-the-bot>`

#### Keep a Heroku bot alive

If you're using the free plan at Heroku, you may want to use this [keep alive script][keep-alive] to keep your bot alive for 18 hour periods each day.

The token bot currently stores its data using redis brain using [this hubot-redis-brain script][hubot-redis-brain]. First create an account at [RedisToGo][redistogo], create an instance, navigate to the webpage for that instance, and find the URL for that Redis instance (it begins with `redis://redistogo:`). Then in a terminal enter
```
heroku config:set REDIS_URL=<your-redis-url>
```

[heroku]: http://www.heroku.com
[heroku-hubot]: https://hubot.github.com/docs/deploying/heroku/
[keep-alive]: https://github.com/hubot-scripts/hubot-heroku-keepalive
[hubot-redis-brain]: https://github.com/hubot-scripts/hubot-redis-brain
[redistogo]: https://redistogo.com/
