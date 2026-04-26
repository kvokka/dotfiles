# Docs for OpenClaw setup for humans

## Telegram group

To ease the setup the group ID is hardcoded in `openclaw.json`, it can be fetched from the telegram client as `-100{peer id from telegram}`

### Grant permissions

#### Manage Topics

The group must be prepared and in the tg interface, click

Group name -> Edit -> Administrators -> `@my_awesome_bot_name_bot` -> Enable `Manage topics`

#### Share messages with the bot without mentioning

1. Open `@BotFather`
2. `/setprivacy`
3. Select `@my_awesome_bot_name_bot`
4. Click on `Disable`

## Openclaw Schema update

in `bin/update_schema.sh` there is a script that update the `openclaw.json` schema and adds it to chezmoi
