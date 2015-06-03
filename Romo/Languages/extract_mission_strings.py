#!/usr/bin/env python

import re, os, plistlib, codecs

print '//--------------------------------------------------------------'
print 'This scripts reads all the mission plists and extracts all the display strings'
print 'It also extracts the Action display strings from RMActions.plist'
print '--------------------------------------------------------------//'

# plist directory should be at: 

#Process all text from the missions files

def extractStringsFromMissions():
	plistDir = '../Content/Missions/'
	outputPath = 'en.lproj/Missions.strings'
	outputFile = codecs.open(outputPath, 'w', 'utf-8')

	for filename in os.listdir(plistDir):
		if filename.endswith('.plist'):
			pl = plistlib.readPlist(plistDir+filename)
			# Remove the extension
			fileTitle = filename.split('.plist')[0]
			print 'Processing: ' + fileTitle

			keysToProcess = ['title', 'briefing', 'prompt', 'failure debriefing', 'success debriefing', 'congrats debriefing']
			# Extract all the display text to a temp dict,
			# which will be added to the Missions.strings file
			localDict = {}

			for key in keysToProcess:
				if key in pl:
					localDict['key'] = fileTitle+'-'+key
					localDict['comment'] = fileTitle+': '+key
					localDict['value'] = re.sub(r'([\"])', r'\\\1',pl[key])
					outputFile.write('/* ' + localDict['comment'] + ' */\n' + '"' + localDict['key'] + '" = "' + localDict['value'] + '";\n\n')

#Process all text from the mission actions file

def extractStringsFromActions():
	plistPath = '../Content/Mission Actions/RMActions.plist'
	outputPath = 'en.lproj/MissionActions.strings'
	outputFile = codecs.open('en.lproj/MissionActions.strings', "w+", 'utf-8')
	
	print 'Processing: ' + outputPath
	pl = plistlib.readPlist(plistPath)

	for action in pl:
		keysToProcess = ['title', 'shortTitle']
		localDict = {}
		for key in keysToProcess:
			if key in action:
				value = re.sub(r'([\"])', r'\\\1',action[key])
				localDict['key'] = 'Action-'+key+'-'+ value
				localDict['comment'] = 'Action '+key+': '+action[key]
				localDict['value'] = value
				outputFile.write('/* ' + localDict['comment'] + ' */\n' + '"' + localDict['key'] + '" = "' + localDict['value'] + '";\n\n')

extractStringsFromMissions()
print '------------------------'
extractStringsFromActions()
