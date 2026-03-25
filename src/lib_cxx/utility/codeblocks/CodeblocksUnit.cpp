#include "CodeblocksUnit.h"

#include "tinyxml2.h"

using namespace tinyxml2;

#include "FilePath.h"

namespace Codeblocks
{
std::string Unit::getXmlElementName()
{
	return "Unit";
}

std::shared_ptr<Unit> Unit::create(const XMLElement* element)
{
	if (!element || element->Value() != getXmlElementName())
	{
		return std::shared_ptr<Unit>();
	}

	std::shared_ptr<Unit> unit(new Unit());

	{
		const char* value = element->Attribute("filename");
		if (!value)
		{
			return std::shared_ptr<Unit>();
		}
		unit->m_filename = value;
	}

	const XMLElement* optionElement = element->FirstChildElement("Option");
	while (optionElement)
	{
		{
			const char* value = optionElement->Attribute("compilerVar");
			if (value)
			{
				unit->m_compilerVar = stringToCompilerVarType(value);
			}
		}
		{
			int value = 0;
			if (optionElement->QueryIntAttribute("compile", &value) == XML_SUCCESS)
			{
				unit->m_compile = (value == 1);
			}
		}
		{
			const char* value = optionElement->Attribute("target");
			if (value)
			{
				unit->m_targetNames.insert(value);
			}
		}

		optionElement = optionElement->NextSiblingElement("Option");
	}

	return unit;
}

FilePath Unit::getCanonicalFilePath(const FilePath& projectFileDirectory) const
{
	FilePath path(m_filename);

	if (!path.exists() || !path.isAbsolute())
	{
		path = projectFileDirectory.getConcatenated(path);
	}

	return path.makeCanonical();
}

CompilerVarType Unit::getCompilerVar() const
{
	return m_compilerVar;
}

bool Unit::getCompile() const
{
	return m_compile;
}

std::set<std::string> Unit::getTargetNames() const
{
	return m_targetNames;
}

Unit::Unit() = default;
}	 // namespace Codeblocks
