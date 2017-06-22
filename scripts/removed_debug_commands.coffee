  # TODO remove this command before putting this into production.
  # robot.respond /reset wallets/i, (res) ->
  #   reset_wallets()
  #   res.send "Just reset wallets"

  # robot.respond /compute_result_of_beauty_contest/i, (res) ->
  #   res.send "If the contest were run right now, the result would be: \n\n
  #     #{Util.inspect tokenBot.compute_result_of_beauty_contest()}"

  # robot.respond /run_mock_beauty_contest/i, (res) ->
  #   res.send "OK, I'll run a mock contest now."
  #   run_beauty_contest_without_resetting_votes()
  #   res.send "Done running a mock contest."





## ****************************************************************************
## ****************************************************************************
## This was copied from right before this 

fail_message = "I didn't understand how many tokens you want to give.
        If you don't provide a number, I assume you want to 
        give one token. I also understand numbers like 1, 2,
        3 and some alphabetic numbers like one, two, three."
## ****************************************************************************

      # if the command was given in a direct message to the bot, 
      # then send a direct message to the recipient to notify them
      # res.send "recipient: {id: #{recipient_id}, name: #{recipient_name}}"
      # res.send "res.envelope = #{Util.inspect res.envelope}"
      # res.send "res.envelope.user.name = #{res.envelope.user.name}"

      # msg.envelope.user.id = recipient_id
      # msg.sendDirect "test"

      # This isn't working yet ...
      # if false #is_direct_message
      #   direct_message = ("Psst. This action was done privately. " + message)
      #   #res.send "Attempting to send the following DM: #{direct_message}"
      #   #res.send "recipient_id = #{recipient_id}"
      #   #res.send "recipient_name = #{recipient_name}"
      #   #res.send "robot.adapter.chatdriver.getDirectMessageRoomId(recipient_name) = #{Util.inspect robot.adapter.chatdriver.getDirectMessageRoomId(recipient_name)}"
      #   #robot.logger.info "robot.adapter.chatdriver.getDirectMessageRoomId(recipient_id).room = #{robot.adapter.chatdriver.getDirectMessageRoomId(recipient).room}"
      #   #robot.adapter.chatdriver.sendMessageByRoomId direct_message, robot.adapter.chatdriver.getDirectMessageRoomId(recipient_name).room
        
      #   # room for the direct message
      #   # TODO: Need to find out how to get the user ID of the bot
      #   robot.logger.info "bot_id = #{bot_id}"
      #   direct_msg_room_id = robot.chatdriver.getDirectMessageRoomId recipient_name
      #   #room_id = [recipient_id, bot_id].sort().join('')
      #   robot.logger.info direct_message
      #   robot.logger.info ("room_id of the DM: " + direct_msg_room_id)
      #   robot.sendDirectToUsername recipient_name, message



  robot.respond /migrate_robot_brain_data_to_private_data/i, (res) ->
    res.send tokenBot.migrate_robot_brain_data_to_private_data()

  robot.respond /reset_tokens_received_to_empty/i, (res) ->
    res.send "About to do reset_tokens_received_to_empty..."
    res.send tokenBot.reset_tokens_received_to_empty()

  robot.respond /populate_tokens_received/i, (res) ->
    res.send "Populating tokens_received..."
    res.send tokenBot.populate_tokens_received()

  robot.respond /set autosave to true/i, (res) ->
    robot.brain.setAutoSave true

  robot.respond /initialize unrecognized users without overwriting/i, (res) ->
    for own key, user of robot.brain.users()
      tokenBot.initialize_user_without_overwriting_data user['id']

