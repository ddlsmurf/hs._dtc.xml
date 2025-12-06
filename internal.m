#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG    "hs._dtc.xml"

#pragma mark - Internal

static const NSErrorDomain errorDomain = (NSErrorDomain)@"org.hammerspoon.extension.hs._dtc.xml.errors";

__attribute__((__format__ (__NSString__, 1, 2)))
static NSError *makeError(NSString *msg, ...) {
    NSError *result;
    va_list valist;
    va_start(valist, msg);
    result = [NSError errorWithDomain:errorDomain
                                 code:924383
                             userInfo:@{
        NSLocalizedDescriptionKey: [[NSString alloc] initWithFormat:msg
                                                          arguments:valist]
    }];
    va_end(valist);
    return result;
}

static void addToDictionaryAsValueOrArray(NSMutableDictionary *container, NSString *key, id value) {
    id<NSObject> existing = [container objectForKey:key];
    if (!existing)
        [container setObject:value forKey:key];
    else if ([existing isKindOfClass:[NSMutableArray class]])
        [(NSMutableArray*)existing addObject:value];
    else
        [container setObject:@[existing, value].mutableCopy forKey:key];
}

static id xmlElementToDictionary(NSXMLElement *element) {
    bool hasAttributes = element.attributes.count > 0;
    bool hasElements = NO;
    if (!hasAttributes)
        for (NSXMLNode *child in element.children)
            if (child.kind == NSXMLElementKind) {
                hasElements = YES;
                break;
            }
    if ((!hasAttributes) && (!hasElements))
        return element.stringValue;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    if (hasAttributes) {
        NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
        [result setObject:attributes forKey:@"_attr"];
        for (NSXMLNode *attribute in element.attributes)
            [attributes setObject:(id _Nonnull)attribute.stringValue
                           forKey:(id _Nonnull)attribute.name];
    }
    for (NSXMLNode *child in element.children) {
        if (child.kind == NSXMLTextKind)
            addToDictionaryAsValueOrArray(result, @"", child.stringValue);
        else if (child.kind == NSXMLElementKind)
            addToDictionaryAsValueOrArray(result, child.name,
                                          xmlElementToDictionary((NSXMLElement *)child));
    }
    return result;
}

static NSDictionary *parseXML(NSString *xml, NSXMLNodeOptions xmlOptions, NSError **error) {
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:xml options:xmlOptions error:error];
    NSDictionary *root = xmlElementToDictionary(doc.rootElement);
    if (*error) {
        NSLog(@"Error parsing XML: %@", *error);
        return nil;
    }
    return [NSDictionary dictionaryWithObject:root forKey:(id _Nonnull)doc.rootElement.name];
}

static NSXMLElement *dictionaryToXMLElement(NSString *name, NSDictionary *contents, NSError **error);

static BOOL appendDictionaryEntryToXMLElement(NSXMLElement *element, NSString *key, id<NSObject> value, NSError **error) {
    if ([key isEqualToString:@"_attr"]) {
        if (![value isKindOfClass:[NSDictionary class]]) {
            *error = makeError(@"Value under attributes key (%@) must be a dictionary but got %@", key, value);
            return NO;
        }
        NSDictionary *valueAsDict = (NSDictionary *)value;
        for (NSString *attributeName in valueAsDict.allKeys) {
            NSString *attributeValue = valueAsDict[attributeName];
            if (!attributeValue)
                continue;
            if (![attributeValue isKindOfClass:[NSString class]]) {
                *error = makeError(@"Value in attributes (%@) must be a string but got %@", attributeName, attributeValue);
                return NO;
            }
            [element addAttribute:[NSXMLNode attributeWithName:attributeName
                                                   stringValue:attributeValue]];
        }
        return YES;
    }
    NSArray *children = [value isKindOfClass:[NSArray class]] ? (NSArray*)value : @[value];
    for (NSDictionary *child in children) {
        if (child == nil)
            continue;
        NSXMLNode *childNode;
        if ([child isKindOfClass:[NSDictionary class]]) {
            childNode = dictionaryToXMLElement(key, child, error);
        } else if ([child isKindOfClass:[NSString class]]) {
            if ([key length])
                childNode = [NSXMLElement elementWithName:key
                                              stringValue:(NSString *)value];
            else
                childNode = [NSXMLNode textWithStringValue:(NSString *)child];
        } else {
            *error = makeError(@"Value for element %@ must be a dictionary or array of dictionnaries or strings, but got an %@", key, child);
            return NO;
        }
        if (*error)
            return NO;
        [element addChild:childNode];
    }
    return YES;
}

static NSXMLElement *dictionaryToXMLElement(NSString *name, NSDictionary *contents, NSError **error) {
    NSXMLElement *element = [NSXMLElement elementWithName:name];
    for (NSString *key in contents.allKeys) {
        if (!appendDictionaryEntryToXMLElement(element, key, contents[key], error)) {
            if (!*error)
                *error = makeError(@"Unexpected error appending element %@", key);
            return nil;
        }
    }
    return element;
}

static NSString *toXML(NSDictionary *root, NSXMLNodeOptions xmlOptions, NSError **error) {
    NSArray *keys = root.allKeys;
    if (keys.count != 1) {
        *error = makeError(@"Root dictionary must have a single key");
        return nil;
    }
    NSString *key = keys[0];
    return [dictionaryToXMLElement(key, root[key], error) XMLStringWithOptions:xmlOptions];
}

#pragma mark - Functions

#pragma mark - Constants

/// hs._dtc.xml.constants
/// Constant
/// Options for XML node parsing, output, and fidelity.
///
/// Notes:
/// This is just a complete list from Foundation. Many don't apply to this simplified XML serialisation.
///
/// These options can be combined using bitwise OR operations.
///
/// Init/Input options:
///  * `NSXMLNodeOptionsNone` - Use the default options
///  * `NSXMLNodeIsCDATA` - This text node is CDATA
///  * `NSXMLNodeExpandEmptyElement` - This element should be expanded when empty, ie `<a></a>`. This is the default.
///  * `NSXMLNodeCompactEmptyElement` - This element should contract when empty, ie `<a/>`
///  * `NSXMLNodeUseSingleQuotes` - Use single quotes on this attribute or namespace
///  * `NSXMLNodeUseDoubleQuotes` - Use double quotes on this attribute or namespace. This is the default.
///  * `NSXMLNodeNeverEscapeContents` - When generating a string representation of an XML document, don't escape the reserved characters '<' and '&' in Text nodes
///
/// Tidy options:
///  * `NSXMLDocumentTidyHTML` - Try to change HTML into valid XHTML
///  * `NSXMLDocumentTidyXML` - Try to change malformed XML into valid XML
///
/// Validation options:
///  * `NSXMLDocumentValidate` - Validate this document against its DTD
///
/// External entity loading options (choose only zero or one):
///  * `NSXMLNodeLoadExternalEntitiesAlways` - Load all external entities instead of just non-network ones
///  * `NSXMLNodeLoadExternalEntitiesSameOriginOnly` - Load non-network external entities and external entities from urls with the same domain, host, and port as the document
///  * `NSXMLNodeLoadExternalEntitiesNever` - Load no external entities, even those that don't require network access
///
/// Parse options:
///  * `NSXMLDocumentXInclude` - Process XInclude directives
///
/// Output options:
///  * `NSXMLNodePrettyPrint` - Output this node with extra space for readability
///  * `NSXMLDocumentIncludeContentTypeDeclaration` - Include a content type declaration for HTML or XHTML
///
/// Fidelity options:
///  * `NSXMLNodePreserveNamespaceOrder` - Preserve the order of namespaces
///  * `NSXMLNodePreserveAttributeOrder` - Preserve the order of attributes
///  * `NSXMLNodePreserveEntities` - Entities should not be resolved on output
///  * `NSXMLNodePreservePrefixes` - Prefixes should not be chosen based on closest URI definition
///  * `NSXMLNodePreserveCDATA` - CDATA should be preserved
///  * `NSXMLNodePreserveWhitespace` - Preserve non-content whitespace
///  * `NSXMLNodePreserveDTD` - Preserve the DTD until it is modified
///  * `NSXMLNodePreserveCharacterReferences` - Preserve character references
///  * `NSXMLNodePromoteSignificantWhitespace` - When significant whitespace is encountered in the document, create Text nodes representing it rather than removing it. Has no effect if NSXMLNodePreserveWhitespace is also specified
///  * `NSXMLNodePreserveEmptyElements` - Remember whether an empty element was in expanded or contracted form
///  * `NSXMLNodePreserveQuotes` - Remember whether an attribute used single or double quotes
///  * `NSXMLNodePreserveAll` - Turn all preservation options on
static void pushNodeOptions(lua_State *L) {
    lua_newtable(L);
    #define ADD_CONST(name) { lua_pushinteger(L, name); lua_setfield(L, -2, #name); }
    // Init options
    ADD_CONST(NSXMLNodeOptionsNone)
    ADD_CONST(NSXMLNodeIsCDATA)
    ADD_CONST(NSXMLNodeExpandEmptyElement)
    ADD_CONST(NSXMLNodeCompactEmptyElement)
    ADD_CONST(NSXMLNodeUseSingleQuotes)
    ADD_CONST(NSXMLNodeUseDoubleQuotes)
    ADD_CONST(NSXMLNodeNeverEscapeContents)

    // Tidy options
    ADD_CONST(NSXMLDocumentTidyHTML)
    ADD_CONST(NSXMLDocumentTidyXML)

    // Validate options
    ADD_CONST(NSXMLDocumentValidate)

    // External entity loading options
    ADD_CONST(NSXMLNodeLoadExternalEntitiesAlways)
    ADD_CONST(NSXMLNodeLoadExternalEntitiesSameOriginOnly)
    ADD_CONST(NSXMLNodeLoadExternalEntitiesNever)

    // Parse options
    ADD_CONST(NSXMLDocumentXInclude)

    // Output options
    ADD_CONST(NSXMLNodePrettyPrint)
    ADD_CONST(NSXMLDocumentIncludeContentTypeDeclaration)

    // Fidelity options
    ADD_CONST(NSXMLNodePreserveNamespaceOrder)
    ADD_CONST(NSXMLNodePreserveAttributeOrder)
    ADD_CONST(NSXMLNodePreserveEntities)
    ADD_CONST(NSXMLNodePreservePrefixes)
    ADD_CONST(NSXMLNodePreserveCDATA)
    ADD_CONST(NSXMLNodePreserveWhitespace)
    ADD_CONST(NSXMLNodePreserveDTD)
    ADD_CONST(NSXMLNodePreserveCharacterReferences)
    ADD_CONST(NSXMLNodePromoteSignificantWhitespace)
    ADD_CONST(NSXMLNodePreserveEmptyElements)
    ADD_CONST(NSXMLNodePreserveQuotes)
    ADD_CONST(NSXMLNodePreserveAll)
    #undef ADD_CONST
}

// Only used by ./init.lua to expose constants, not exposed to the user
static int target__getConstants(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    pushNodeOptions(L);
    return 1;
}

/// hs._dtc.xml.xmlToTable(xml[, options]) -> table
/// Method
/// Parse an XML string into a structure of lua tables
///
/// Parameters:
///  * xml - (string) The XML formatted string
///  * options - (number) Value from `hs.xml.constants`. Defaults to `NSXMLDocumentTidyXML`.
///
/// Returns:
///  * A table structure, normally with a single key set to the root element.
///
/// Notes:
///  * For each element, if it contains no attributes nor elements, is converted as a simple string
///  * Otherwise it is a dictionary that contains any of the following keys:
///    * `"_attr"`: a dictionary of attributes (if an `<_attr>` element somehow also
///                 exists, will be a table where the attributes are the first item)
///    * `""`: an empty string key will hold any text text content, or a table of text content if mixed
///    * *element_name*: child elements are stored by their name. If multiple exist they are collected into a table.
static int target_xmlToTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    NSString *xml = [skin toNSObjectAtIndex:1];
    lua_Integer xmlOptions = (lua_gettop(L) >= 2) ? lua_tointeger(L, 2) : NSXMLDocumentTidyXML;
    NSError *error = nil;
    id<NSObject> result = parseXML(xml, (NSXMLNodeOptions)xmlOptions, &error);
    if (error)
        return luaL_error(L, [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
    [skin pushNSObject:result];
    return 1;
}

/// hs._dtc.xml.tableToXML(table[, options]) -> string
/// Method
/// Convert a table in the format as returned by `hs._dtc.xml.xmlToTable` to an XML string. This is lossful and simplified.
///
/// Parameters:
///  * table - (table) A table with a single key that will be the root element
///  * options - (number) Value from `hs.xml.constants`. Defaults to `NSXMLNodePrettyPrint`.
///
/// Returns:
///  * An XML formatted string
///
/// Notes:
///  * All leaf values must be strings
static int target_tableToXML(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    NSDictionary *data = (NSDictionary *)[skin toNSObjectAtIndex:1];
    if (![data isKindOfClass:[NSDictionary class]])
        return luaL_error(L, "Expect table with a single key as first argument");
    lua_Integer xmlOptions = (lua_gettop(L) >= 2) ? lua_tointeger(L, 2) : NSXMLNodePrettyPrint;
    NSError *error = nil;
    NSString *result = toXML(data, (NSXMLNodeOptions)xmlOptions, &error);
    if (error)
        return luaL_error(L, [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
    [skin pushNSObject:result];
    return 1;
}

#pragma mark - Module

static luaL_Reg moduleLib[] = {
    {"xmlToTable", target_xmlToTable},
    {"tableToXML", target_tableToXML},
    {"_getConstants", target__getConstants},
    {NULL,  NULL}
};

#pragma mark - Lua Module Initialization

static int refTable;
int luaopen_hs__dtc_xml_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:nil] ;
    return 1;
}
