import requests
import bs4
import urllib
import sys

github = 'https://github.com/arduino/Arduino/tree/master/hardware/arduino/avr/'
rawgithub = 'https://raw.githubusercontent.com/arduino/Arduino/master/hardware/arduino/avr/'

core = 'cores/arduino/'
variant = 'variants/' + str(sys.argv[1]) + '/'

file_list = []

response = requests.get(github + core)
soup = bs4.BeautifulSoup(response.text, "html.parser")
scraped = soup.select('span.css-truncate.css-truncate-target a[class^=js-navigation-open]')
for filename in scraped:
	urllib.urlretrieve(rawgithub + core + filename.text, filename=str(sys.argv[2]) + filename.text)
	file_list.append(filename.text)

response = requests.get(github + variant)
soup = bs4.BeautifulSoup(response.text, "html.parser")
scraped = soup.select('span.css-truncate.css-truncate-target a[class^=js-navigation-open]')
for filename in scraped:
	urllib.urlretrieve(rawgithub + variant + filename.text, filename=str(sys.argv[2]) + filename.text)
	file_list.append(filename.text)