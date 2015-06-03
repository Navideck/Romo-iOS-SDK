#!/usr/bin/env python

import re, os, json, codecs

# debug
from pprint import pprint

print '//--------------------------------------------------------------'
print 'This scripts reads all the interaction scripts and extracts all text strings'
print '--------------------------------------------------------------//'

# plist directory should be at: 

#Process all text from the missions files

def extractStringsFromInteractionScripts():
	scriptsDir = '../Content/Character Scripts/'
	outputPath = 'en.lproj/CharacterScripts.strings'
	outputFile = codecs.open(outputPath, 'w', 'utf-8')

	for filename in os.listdir(scriptsDir):
		# Make sure it's a json extension
		if filename.endswith('.json'):
			# Remove the extension
			fileTitle = filename.split('.plist')[0]
			print 'Processing: ' + fileTitle

			jsonFile = open(scriptsDir+filename, 'r')
			data = json.load(jsonFile)

			exportArray = []

			# Need to Process:
			## say, sayRandomFromList, mumbleWithText, mumbleWithRandomTextFromList, expressionWithText, ask

			for block in data['script']['blocks']:
				for action in block['actions']:
					# Extract all the display text to a temp dict,
					# which will be added to the CharacterScripts.strings file
					localDict = {}

					localDict['comment'] = data['script']['name'] + ' ' + block['description']
					localDict['values'] = []

					if action['name'] == 'say' or action['name'] == 'mumbleWithText':
						localDict['values'] = [ action['args'][0] ]
					elif action['name'] == 'sayRandomFromList' or action['name'] == 'mumbleWithRandomTextFromList':
						localDict['values'] = action['args']
					elif action['name'] == 'expressionWithText':
						text = action['args'][1]
						if len(action['args']) > 2:
							text = action['args'][2]
						localDict['values'] = [ text ]
					elif action['name'] == 'ask':
						localDict['values'] = action['args']

					for value in localDict['values']:
						exportArray.append({ 'comment': localDict['comment'], 'value': value })
			
			# Write to the file
			if len(exportArray) > 0:
				for item in exportArray:
					item['value'] = item['value'].replace('\n','%n')
					outputFile.write('/* ' + item['comment'] + ' */\n' + '"' + item['value'] + '" = "' + item['value'] + '";\n\n')

			# for key in keysToProcess:
			# 	if key in pl:
			# 		localDict['key'] = fileTitle+'-'+key
			# 		localDict['comment'] = fileTitle+': '+key
			# 		localDict['value'] = re.sub(r'([\"])', r'\\\1',pl[key])
			# 		outputFile.write('/* ' + localDict['comment'] + ' */\n' + '"' + localDict['key'] + '" = "' + localDict['value'] + '";\n\n')

extractStringsFromInteractionScripts()