#ifndef UTILITY_XML_H
#define UTILITY_XML_H

#include <memory>
#include <string>
#include <vector>

#include "TextAccess.h"

namespace tinyxml2 { class XMLElement; }

namespace utility
{
bool xmlElementHasAttribute(const tinyxml2::XMLElement* element, const std::string& attributeName);

std::vector<const tinyxml2::XMLElement*> getXmlChildElementsWithName(
	const tinyxml2::XMLElement* parentElement, const std::string& elementName);
std::vector<const tinyxml2::XMLElement*> getXmlChildElementsWithAttribute(
	const tinyxml2::XMLElement* parentElement,
	const std::string& attributeName,
	const std::string& attributeValue);

std::vector<std::string> getValuesOfAllXmlElementsOnPath(
	std::shared_ptr<TextAccess> textAccess, const std::vector<std::string>& tags);
std::vector<std::string> getValuesOfAllXmlTagsByName(
	std::shared_ptr<TextAccess> textAccess, const std::string& tag);
std::vector<tinyxml2::XMLElement*> getAllXmlTagsByName(tinyxml2::XMLElement* root, const std::string& tag);
}	 // namespace utility

#endif	  // UTILITY_XML_H
