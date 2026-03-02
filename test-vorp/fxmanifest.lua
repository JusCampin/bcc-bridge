fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
author 'BCC Team'
description 'bcc-bridge VORP test suite – extract this folder to your resources and start it.'

-- bcc-bridge must be started before this resource
dependencies { 'bcc-bridge' }

server_scripts { 'server/test.lua' }
client_scripts { 'client/test.lua' }
