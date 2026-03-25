#include "CodeblocksCompiler.h"

#include "tinyxml2.h"

using namespace tinyxml2;

namespace Codeblocks
{
std::string Compiler::getXmlElementName()
{
	return "Compiler";
}

std::shared_ptr<Compiler> Compiler::create(const XMLElement* element)
{
	if (!element || element->Value() != getXmlElementName())
	{
		return std::shared_ptr<Compiler>();
	}

	std::shared_ptr<Compiler> compiler(new Compiler());

	{
		const XMLElement* addElement = element->FirstChildElement("Add");
		while (addElement)
		{
			{
				const char* value = addElement->Attribute("option");
				if (value)
				{
					compiler->m_options.push_back(value);
				}
			}
			{
				const char* value = addElement->Attribute("directory");
				if (value)
				{
					compiler->m_directories.push_back(value);
				}
			}

			addElement = addElement->NextSiblingElement("Add");
		}
	}

	return compiler;
}

const std::vector<std::string>& Compiler::getOptions() const
{
	return m_options;
}

const std::vector<std::string>& Compiler::getDirectories() const
{
	return m_directories;
}
}	 // namespace Codeblocks
