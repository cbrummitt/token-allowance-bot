# Description:
#   Track tokens given to acknowledge contributions from others
#
# Dependencies:
#   None
#
# Configuration:
#   TOKEN_ALLOW_SELF
#
# Commands:
#   hubot give (a) token (to) @user_name - gives a token to @user_name. 'a' and 'to' are optional.
#   hubot revoke (a) token (from) @user_name - revokes a token from @user_name. 'a' and 'from' are optional.
#   hubot token status (of) @user_name - check the status of @user_name's tokens (given and received). 'of' is optional.
#
# Author:
#   cbrummitt


## TODO: Update the commands list above. 
## From the scripting documentation: 
#####  At load time, Hubot looks at the Commands section of each scripts, and build a list of all commands. 
##### The included help.coffee lets a user ask for help across all commands, or with a search. 
##### Refer to the Hubot as hubot, even if your hubot is named something else. It will automatically be replaced with the correct name. This makes it easier to share scripts without having to update docs.


#### Commands from karma bot: 
#   <thing>++ - give thing some karma
#   <thing>-- - take away some of thing's karma
#   hubot karma <thing> - check thing's karma (if <thing> is omitted, show the top 5)
#   hubot karma empty <thing> - empty a thing's karma
#   hubot karma best - show the top 5
#   hubot karma worst - show the bottom 5


# ##### begin Charlie's code #######

# Environment variables:
#   TOKEN_ALLOW_SELF = false

class TokenNetwork
  #### Constructor ####
  constructor: (@robot) -> 
    # a dictionary of whose tokens have been given to whom. The data is in the form 
    #     sender : [recipient1, recipient2, ...]
    @tokens_given = {}

    # a dictionary of who has received tokens from whom. The data is in the form 
    #     recipient : [sender1, sender2, ...]
    @tokens_received = {}
    
    # each user can give at most this many tokens to others
    # TODO: make this an environment variable? See `allow_self = process.env.KARMA_ALLOW_SELF or "true"` in the karma bot
    @max_tokens_per_user = 5 

    # variable that determines whether tokens can be given right now
    # TDOO: write a method that will turn this off and display a message in #general telling everyone that tokens can no longer be given?
    # TODO: make these environment variables ` ... = process.env.HUBOT_CAN_GIVE_REVOKE_TOKENS or true`
    @tokens_can_be_given = true
    @tokens_can_be_revoked = true

    # list of responses to display when someone receives or gives a token
    @receive_token_responses = ["received a token!", "was thanked with a token!"]
    @revoke_token_responses = ["lost a token :(", "had a token revoked"]

    # if the brain was already on, then set the cache to the dictionary @robot.brain.data.tokens_given
    # the fat arrow `=>` binds the current value of `this` (i.e., `@`) on the spot
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.tokens_given
        @tokens_given = @robot.brain.data.tokens_given


  #### Methods ####

  freeze_tokens: (allow_tokens_to_be_sent_or_received) -> 
    @tokens_can_be_given = allow_tokens_to_be_sent_or_received
    @tokens_can_be_revoked = allow_tokens_to_be_sent_or_received

  give_token: (sender, recipient) -> 
    # check whether tokens can be given. Returns a message to send to the chat channel.
    # TODO: do this in the method that listens for the command? If @tokens_can_be_given is false, then we should display the message `Tokens can no longer be given.`
    if @tokens_can_be_given

      # check whether @cacheTokens[sender] exists and if not set it to []
      if @tokens_given[sender]? == false # if @tokens_given[sender] has not yet been defined (i.e., it's null or undefined)
        @tokens_given[sender] = []

      if @tokens_received[recipient]? == false
        @tokens_received[recipient] = []

      # temp = {"a" : 1, "b" : 2}
      # temp_str = ""
      # temp_str += name + " has " + " tokens" for name, cnt in temp
      # return temp_str #"@tokens_given = #{@tokens_given}"

      # if the sender has not already given out more that `@max_tokens_per_user` tokens, then add recepient to @cacheTokens[sender]'s list.
      # note that this allows someone to send multiple tokens to the same user
      if @tokens_given[sender].length < @max_tokens_per_user
        @tokens_given[sender].push recipient
        @robot.brain.data.tokens_given = @tokens_given

        # update @tokens_received
        @tokens_received[recipient].push sender
        @robot.brain.data.tokens_received = @tokens_received
        
        return "#{sender} gave one token to #{recipient}." + "#{recipient} has received tokens from @tokens_received[recipient] = #{@tokens_received[recipient]}"
      else
        return "#{sender}: you do not have any more tokens available to give to others. If you want, revoke a token using the command `revoke @user_name`."

    else
      return "Sorry #{sender}, tokens can no longer be given nor revoked."
      # TODO: if @tokens_given[sender].length >= @max_tokens_per_user, we want to send a message to the user saying that they've already given out all their tokens
      # Send a message like the following:
      #     You do not have any more tokens to give out. Type "token status" to find out to whom you have given your tokens, and type "token revoke @username" to revoke a token from @username.

      # TODO: send a message that announces that a token was given using a command like
      #       msg.send "#{subject} #{karma.receive_token_response()} (Karma: #{karma.get(subject)})"
      # in the robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) function (or the equivalent that we write)

  revoke_token: (sender, recipient) ->
    # remove recipient from @tokens_given[sender] and remove sender from @tokens_received[recipient] 
    # note that if the sender has given >1 token to recipient, this will remove just one of those tokens from the recipient.
    
    # first check whether @tokens_can_be_revoked == false; if so, then return with a message.
    if not @tokens_can_be_revoked
      return "Sorry #{sender}, tokens can no longer be given nor revoked."
    else  
      # check whether @tokens_given[sender] or @tokens_received[recipient] is null or undefined
      if not @tokens_given[sender]?
        return "#{sender} has not given tokens to anyone."
      else if not @tokens_received[recipient]
        return "#{sender} has not given any tokens to #{recipient}."
      else
        # remove recipient from @tokens_given[sender]
        index = @tokens_given[sender].indexOf recipient
        @tokens_given.splice index, 1 if index isnt -1

        # remove sender from @tokens_received[recipient]
        index = @tokens_received[recipient].indexOf sender
        @tokens_received.splice index, 1 if index isnt -1

        if index isnt -1
          return "#{sender} revoked one token from #{recipient}."
        else
          return "#{sender}: #{recipient} does not have any tokens from you, so you cannot revoke a token from #{recipient}."
    # TODO: send a message using 
    #       msg.send "#{subject} #{karma.revoke_token_response()} (Karma: #{karma.get(subject)})"
    # in the robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) function
  # return a uniformly random response for giving a token to someone someone's karma

  receive_token_response: ->
    @receive_token_responses[Math.floor(Math.random() * @receive_token_responses.length)]

  revoke_token_response: ->
    @revoke_token_responses[Math.floor(Math.random() * @revoke_token_responses.length)]

  selfDeniedResponses: (name) ->
    @self_denied_responses = [
      "Sorry #{name}. Tokens cannot be given to oneself.",
      "I can't do that #{name}.",
      "Tokens can only be given to other people."
    ]

  tally: (list_of_strings) -> 
    count = {}
    for x in list_of_strings
      if count[x]? then count[x] += 1 else count[x] = 1
    return count

  status: (name) -> 
    # return the number of tokens given and to whom

    # list of the people to whom `name` has given tokens
    tokens_given_by_this_person = if @tokens_given[name]? then @tokens_given[name] else []
    num_tokens_given = tokens_given_by_this_person.length


    # build up a string of results
    result = ""

    # number of tokens this person has left to give others
    tokens_remaining = @max_tokens_per_user - num_tokens_given
    result += "#{name} has " + tokens_remaining + " token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "

    if num_tokens_given > 0
      result += "#{name} has given " + num_tokens_given + "token" + (if num_tokens_given != 1 then "s" else "") + " to the following people:\n"
      for own name, number of @tally(tokens_given_by_this_person)
        result += "\t#{name}: #{number} token" + (if number != 1 then "s" else "") + "\n"
    else
      result += "#{name} has not given any tokens to other people. "


    # tokens received from others
    tokens_received_by_this_person = if @tokens_received[name]? then @tokens_received[name] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      result += "#{name} has received " + num_tokens_received + " token" + (if num_tokens_received != 1 then "s" else "") + " from the following people:\n"
      for own name, number of @tally(tokens_received_by_this_person)
        result += "\t#{name}: #{number} token" + (if number != 1 then "s" else "") + "\n"
    else
      result += "#{name} has not received any tokens from other people."

    return result
    # displays how many of your tokens you still have, and how many you have given to other people, 
    # and how many tokens you have received from other users

    # Example:
    # You have 2 of your own tokens in your pocket. 
    # You have given tokens to the following people: 
    # @user_4 (1 token)
    # @user_8 (2 tokens) 
    # You have received 2 tokens from others: 
    # @user_4 (1 token)
    # @user_5 (1 token)
    

    # in the code that listens for this command, we could display this if 
    #       msg.message.user.name.toLowerCase() == subject 
    # where subject = subject = msg.match[1].toLowerCase()
    # Way to go! Get more tokens by contributing to others' ideas. Each token from a winning business proposal earns prize money.



# the script must export a function. `robot` is an instance of the bot.
module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  verbose = true

  # we export a function of one variable, the `robot`, which `.hear`s messages and then does stuff

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME


  # environment variables
  allow_self = process.env.TOKEN_ALLOW_SELF # whether someone can give a token to himself

  robot.respond /test bot name/, (res) -> 
    res.send "the bot name is #{bot_name}"

  robot.hear /badger/i, (res) ->
    res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS!123"

  #robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) ->
  # respodnd to `give a token @user_name`
  robot.respond ///
                (give|send)         # give or send
                (\sa)?              # a is optional
                \stokens{0,1}       # token or tokens
                (\sto)?             # to is optional
                \s                  # whitespace
                @?([\w .\-]+)*$   # user name or name (to be matched in a fuzzy way below)
                ///, (res) ->
    
    # `res` is an instance of Response. 
    sender = res.message.user.name
    recipients = robot.brain.usersForFuzzyName(res.match[4].trim()) # the fourth capture group is the name 
    ## TODO: does this handle errors with the name not a username? 
    ## what does this command do if I give it "/give token xxx" where "xxx" isn't the name of a user?
    
    if not (recipients.length >= 1)
      res.send "Sorry, I didn't understand that user name #{res.match[4]}."
    else
      recipient = recipients[0]

      if verbose
        res.send "called give a token"
        res.send "the sender is #{sender}"
        res.send "the recipient is #{recipient}"
        res.send "hi #{sender}! thanks for asking to give a token to #{recipient}!"
      if allow_self is true or res.message.user.name != recipient
        message = tokenBot.give_token res.message.user.name, recipient
        res.send message
        #karma.increment subject
        #msg.send "#{subject} #{karma.incrementResponse()} (Karma: #{karma.get(subject)})"
      else
        res.send res.random tokenBot.selfDeniedResponses(res.message.user.name)

  # respond to "status (of) @user"
  robot.respond ///            # beginning of line
                status           # "status"
                (\sof)?           # "of" is optional
                \s               # whitespace
                @?([\w .\-]+)*   # user name or name (to be matched in a fuzzy way below). \w matches any word character (alphanumeric and underscore).
                ///, (res) ->
    # for debugging: 
    res.send "the status `respond` fired; the name provided is #{res.match[2]}"

    if not res.match[2]?
      res.send "Sorry, I couldn't understand the name you provided, which was #{res.match[2]}."
    else
      users = robot.brain.usersForFuzzyName(res.match[2].trim()) # the second capture group is the user name
      if not (users.length >= 1)
        res.send "Sorry, I didn't understand that user name #{res.match[2]}."
      else
        user = users[0]
        res.send tokenBot.status user

###### end Charlie's code #######



