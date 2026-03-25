#include "utilityXml.h"

#include "tinyxml2.h"

#include "logging.h"

using namespace tinyxml2;

namespace utility
{
bool xmlElementHasAttribute(const XMLElement* element, const std::string& attributeName)
{
	return (element->Attribute(attributeName.c_str()) != nullptr);
}

std::vector<const XMLElement*> getXmlChildElementsWithName(
	const XMLElement* parentElement, const std::string& elementName)
{
	std::vector<const XMLElement*> elements;

	for (const XMLElement* child = parentElement->FirstChildElement(elementName.c_str()); child;
		 child = child->NextSiblingElement(elementName.c_str()))
	{
		elements.push_back(child);
	}

	return elements;
}

std::vector<const XMLElement*> getXmlChildElementsWithAttribute(
	const XMLElement* parentElement,
	const std::string& attributeName,
	const std::string& attributeValue)
{
	std::vector<const XMLElement*> elements;

	for (const XMLElement* child = parentElement->FirstChildElement(); child;
		 child = child->NextSiblingElement())
	{
		const char* value = child->Attribute(attributeName.c_str());
		if (value != nullptr && value == attributeValue)
		{
			elements.push_back(child);
		}
	}

	return elements;
}

std::vector<std::string> getValuesOfAllXmlElementsOnPath(
	std::shared_ptr<TextAccess> textAccess, const std::vector<std::string>& tags)
{
	std::vector<std::string> values;

	std::string text = textAccess->getText();

	XMLDocument doc;
	doc.Parse(text.c_str());
	if (!doc.Error())
	{
		XMLHandle docHandle(doc);
		std::vector<std::pair<XMLElement*, size_t>> traversalStates;
		traversalStates.push_back(std::make_pair(docHandle.ToNode()->FirstChildElement(), 0));

		while (!traversalStates.empty())
		{
			XMLElement* currentElement = traversalStates.back().first;
			const size_t currentIndex = traversalStates.back().second;
			traversalStates.pop_back();

			if (currentElement != nullptr && currentElement->Value() == tags[currentIndex])
			{
				if (currentIndex < tags.size() - 1)
				{
					XMLElement* nextElement = currentElement->FirstChildElement();

					while (nextElement)
					{
						traversalStates.push_back(
							std::make_pair(nextElement, size_t(currentIndex + 1)));
						nextElement = nextElement->NextSiblingElement();
					}
				}
				else
				{
					if (currentElement->FirstChild() &&
						currentElement->FirstChild() == currentElement->LastChild() &&
						currentElement->FirstChild()->ToText())
					{
						values.push_back(currentElement->FirstChild()->ToText()->Value());
					}
				}
			}
		}
	}
	else
	{
		LOG_ERROR(
			std::string("Error while parsing XML: ") + doc.ErrorStr() + " (in line " +
			std::to_string(doc.ErrorLineNum()) + ": \"" + textAccess->getLine(doc.ErrorLineNum()) +
			"\")");
	}
	return values;
}

std::vector<std::string> getValuesOfAllXmlTagsByName(
	std::shared_ptr<TextAccess> textAccess, const std::string& tag)
{
	std::vector<std::string> values;

	std::string text = textAccess->getText();

	XMLDocument doc;
	doc.Parse(text.c_str());
	if (!doc.Error())
	{
		XMLHandle docHandle(doc);
		XMLElement* rootElement = docHandle.ToNode()->FirstChildElement();
		if (rootElement != nullptr)
		{
			for (XMLElement* element: getAllXmlTagsByName(rootElement, tag))
			{
				if (element->FirstChild() && element->FirstChild() == element->LastChild() &&
					element->FirstChild()->ToText())
				{
					values.push_back(element->FirstChild()->ToText()->Value());
				}
			}
		}
		else
		{
			//	LOG_ERROR("Unable to load file.");
		}
	}
	else
	{
		//	LOG_ERROR("Unable to load file.");
	}
	return values;
}

std::vector<XMLElement*> getAllXmlTagsByName(XMLElement* root, const std::string& tag)
{
	std::vector<XMLElement*> nodes;

	XMLElement* element = root;

	while (element)
	{
		std::string value = element->Value();

		if (value == tag)
		{
			nodes.push_back(element);
		}

		if (element->FirstChildElement() != nullptr)
		{
			element = element->FirstChildElement();
		}
		else if (element->NextSiblingElement() != nullptr)
		{
			element = element->NextSiblingElement();
		}
		else
		{
			if (element == nullptr)
			{
			}

			while (element->Parent()->ToElement() != nullptr &&
				   element->Parent()->NextSiblingElement() == nullptr)
			{
				XMLElement* newElement = element->Parent()->ToElement();

				if (newElement == nullptr)
				{
				}

				element = newElement;
			}
			if (element->Parent() != nullptr && element->Parent()->NextSiblingElement() != nullptr)
			{
				element = element->Parent()->NextSiblingElement();
			}
			else
			{
				break;
			}
		}
	}

	return nodes;
}
}	 // namespace utility
