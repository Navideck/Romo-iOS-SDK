#!/usr/bin/env python

# input must be a utf-8 file!

import re, codecs, os

print '//--------------------------------------------------------------'
print 'This scripts takes an file outputed from the genstrings command'
print 'in the Romo project and populates the values with the comments'
print 'Make sure you only run this ONCE after every genstrings process'
print '--------------------------------------------------------------//'

# userInput = raw_input('Localizable.strings file path: ')

userInput = 'en.lproj/Localizable.strings'

stringsFile = codecs.open(userInput, "r", 'utf-16')

currentComment = ''
# An array to store all the values to write
exportArray = []

for line in stringsFile:

	commentPattern = re.compile('\/\* (?P<comment>.*) \*\/')
	commentMatch = re.match(commentPattern, line)

	keyValuePattern = re.compile('"(?P<key>.*)" = "(?P<value>.*)";')
	keyValueMatch = re.match(keyValuePattern, line)

	# if this line is a comment, then store the comment
	if commentMatch:
		currentComment = commentMatch.group('comment')
	elif keyValueMatch:
		# if this line follows a comment and it has a key value match,
		# then it's likey to be directly associated to the comment just stored
		if currentComment != '' and currentComment != 'No comment provided by engineer.':
			# protection against running the script twice in a row
			if currentComment != keyValueMatch.group('key'):
				currentDict = { 'key': keyValueMatch.group('key'), 'comment': currentComment, }
				exportArray.append(currentDict)

	else:
		currentComment = ''

if len(exportArray) > 0:
	outputFile = codecs.open(userInput, "w+", 'utf-8')
	for pair in exportArray:
		outputFile.write('/* ' + pair['key'] + ' */\n' + '"' + pair['key'] + '" = "' + pair['comment'] + '";\n\n')
else:
	print 'Do not run this script twice in a row on the same file'

