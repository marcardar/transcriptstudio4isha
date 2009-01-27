/*
   Transcript Markups Editor: An XML based application that allows users to define 
   and store contextual metadata for contiguous sections within a text document. 

   Copyright 2008 Mark Carter, Swami Kevala

   This file is part of Transcript Markups Editor.

   Transcript Markups Editor is free software: you can redistribute it and/or modify it 
   under the terms of the GNU General Public License as published by the Free Software 
   Foundation, either version 3 of the License, or (at your option) any later version.

   Transcript Markups Editor is distributed in the hope that it will be useful, but 
   WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along with 
   Transcript Markups Editor. If not, see http://www.gnu.org/licenses/.
*/

package org.ishafoundation.archives.transcript.model
{
	import mx.controls.Alert;
	
	import name.carter.mark.flex.project.mdoc.MTag;
	import name.carter.mark.flex.util.XMLUtils;
	import name.carter.mark.flex.util.collection.HashSet;
	import name.carter.mark.flex.util.collection.ISet;
	
	import org.ishafoundation.archives.transcript.db.*;

	/**
	 * Consider building dynamic maps allowing faster lookup of search terms (words).
	 * For example, a map from search term to category name array (matching on tags and/or category name)
	 * Also, a map from search term to descendants (and self) in the hierarchy (set of tag names)
	 * Also, a map from search term to synonyms (and self)
	 */
	public class ReferenceManager {

		public static const REFERENCE_XML_PATH:String = DatabaseConstants.REFERENCE_COLLECTION_PATH + "/reference.xml";
		
		private var xmlRetrieverStorer:XMLRetrieverStorer;
		private var xqueryExecutor:XQueryExecutor;
		
		[Bindable]
		public var referenceXML:XML;
		
		[Bindable]
		public var unsavedChanges:Boolean = false;
			
		public function ReferenceManager(xmlRetrieverStorer:XMLRetrieverStorer, xqueryExecutor:XQueryExecutor) {
			this.xmlRetrieverStorer = xmlRetrieverStorer;
			this.xqueryExecutor = xqueryExecutor;
		}	
		
		public function loadReferences(retrieveXMLSuccess:Function, retrieveXMLFailure:Function):void {
			// recreate the xmlRetriever because the old one might be still in progress (not timedout)
			this.xmlRetrieverStorer.retrieveXML(REFERENCE_XML_PATH, function(xml:XML):void {
				referenceXML = xml;
				unsavedChanges = false;
				retrieveXMLSuccess();
			}, retrieveXMLFailure);
		}
		
		public function storeReferences(successFunction:Function = null, failureFunction:Function = null):void {
			if (referenceXML == null) {
				throw new Error("Cannot store reference xml because it is null");
			}
			if (!unsavedChanges) {
				Alert.show("Saving reference file even though there were no changes made");
			}
			this.xmlRetrieverStorer.storeXML(REFERENCE_XML_PATH, referenceXML, function ():void {
				trace("References saved");
				unsavedChanges = false;
				if (successFunction != null) {
					successFunction();
				}
			}, function(msg:String):void {
				trace("Failed to store references because: " + msg);
				if (failureFunction != null) {
					failureFunction(msg);
				};
			});
		}
		
		/**
		 * Each search term (or related concept) must exist (in name or tag) for the category to be returned.
		 * 
		 * For each search term:
		 * 1. Find all concepts containing a word prefixed by this search time
		 * 2. Expand results to include synonyms
		 * 3. Further expand results to include descendants
		 * 4. Add results from category name search
		 */
		public function searchCategories(searchTerms:ISet):Array {
			var resultSet:ISet = null;
			for each (var searchTerm:Object in searchTerms.toArray()) {
				var resultsForThisSearchTerm:ISet;
				if (searchTerm is MTag) {
					// this is a special tag - so forget about prefixes, synonyms, descendants etc
					resultsForThisSearchTerm = getCategoriesTaggedWith(searchTerm as MTag);
				}
				else {
					var searchTermString:String = searchTerm as String;
					// first expand the search term by assuming this is a prefix
					var searchConcepts:ISet = new HashSet();
					for each (var samePrefixConceptId:String in getConceptIdsStartingWith(searchTermString).toArray()) {
						searchConcepts.addAll(getCollectedConceptIds(samePrefixConceptId).toArray());
					}
					trace("Must contain one of these: " + searchConcepts + " or category name include: " + searchTerm);
					resultsForThisSearchTerm = getCategoriesTaggedWithAtLeastOneConcept(searchConcepts);
					// also look at the category names
					var categoryElements:XMLList = this.referenceXML.markupCategories.markupCategory.(containsWordPrefixedWith(attribute("name"), searchTerm));
					for each (var categoryElement:XML in categoryElements) {
						resultsForThisSearchTerm.add(categoryElement.@id.toString());
					}
				}
				if (resultSet == null) {
					resultSet = resultsForThisSearchTerm;
				}
				else {
					resultSet.retainAll(resultsForThisSearchTerm.toArray());
				}
			}
			if (resultSet == null) {
				return new Array();
			}
			else {
				return resultSet.toArray();
			}
		}
		
		public function getAllConceptIds():ISet {
			// first look at the categories
			var result:ISet = new HashSet();
			for each (var categoryId:String in getAllCategories()) {
				result.addAll(getConceptIdsForCategory(categoryId));
			}
			// now look at the concept hierarchy and synonym groups
			result.addAll(XMLUtils.convertToStringISet(referenceXML.concepts.concept.@id).toArray());
			result.addAll(XMLUtils.convertToStringISet(referenceXML.concepts.concept.concept.@idRef).toArray());
			result.addAll(XMLUtils.convertToStringISet(referenceXML.synonyms.synonym.concept.@idRef).toArray());
			return result;
		}
		
		private function getConceptIdsForCategory(categoryId:String):Array {
			var result:Array = new Array();
			var categoryElement:XML = getCategoryElement(categoryId);
			for each (var tagElement:XML in categoryElement.tag.(@type == "concept")) {
				var concept:String = tagElement.@value;
				result.push(concept);
			}
			return result;
		}
		
		public function getAllCategories():Array {
			var categoryElements:XMLList = this.referenceXML.markupCategories.markupCategory;
			var result:Array = new Array();
			for each (var categoryElement:XML in categoryElements) {
				result.push(categoryElement.@id.toString());
			}
			return result;
		}
		
		/**
		 * Two category names are considered the same if after removing whitespace and
		 * converting to lowercase, the strings are equal
		 */
		public function isNewCategoryNameValid(categoryName:String):Boolean {
			var nameAttrs:XMLList = referenceXML.markupCategories.markupCategory.@name;
			var newNormalizedName:String = normalizeString(categoryName);
			if (newNormalizedName.length == 0) {
				return false;
			}
			for each (var name:String in nameAttrs) {
				var normalizedName:String = normalizeString(name);
				if (normalizedName == newNormalizedName) {
					return false;
				}
			}
			return true;
		}
		
		private static function normalizeString(str:String):String {
			var result:String = str.toLowerCase();
			var regExp:RegExp = /[^a-z]/g;
			result = result.replace(regExp, "");
			return result;
		}
		
		private function getCategoriesTaggedWith(tag:MTag):ISet {
			var result:ISet = new HashSet();
			var tagElements:XMLList = this.referenceXML.markupCategories.markupCategory.tag.(@type == tag.type && @value == tag.value);
			for each (var tagElement:XML in tagElements) {
				var categoryElement:XML = tagElement.parent() as XML;
				result.add(categoryElement.@id.toString());
			}
			return result;
		}
		
		private function getCategoriesTaggedWithConcept(concept:String):ISet {
			var result:ISet = new HashSet();
			var tagElements:XMLList = this.referenceXML.markupCategories.markupCategory.tag.(@type == "concept" && @value == concept);
			for each (var tagElement:XML in tagElements) {
				var categoryElement:XML = tagElement.parent() as XML;
				result.add(categoryElement.@id.toString());
			}
			return result;
		}
		
		private function getCategoriesTaggedWithAtLeastOneConcept(concepts:ISet):ISet {
			var result:ISet = new HashSet();
			for each (var concept:String in concepts.toArray()) {
				var categoriesForConcept:ISet = getCategoriesTaggedWithConcept(concept);
				result.addAll(categoriesForConcept.toArray());
			}
			return result;
		}
		
		public function getConceptSubTypes(conceptId:String):ISet {
			return XMLUtils.convertToStringISet(this.referenceXML.concepts.concept.(@id == conceptId).concept.@idRef);
		}
		
		public function getTopLevelConceptElementInHierarchy(conceptId:String):XML {
			var conceptElements:XMLList = this.referenceXML.concepts.concept.(@id == conceptId);
			switch (conceptElements.length()) {
				case 0:
					return null;
				case 1:
					return conceptElements[0];
				default:
					throw new Error("Concept appears more than once in top level of concept hierarchy: " + conceptId);
			}			
		}
		
		/**
		 * Always at least one item
		 */
		private function getConceptDescendantsAndSelf(conceptId:String):ISet {
			var result:ISet = new HashSet();
			traverseConceptDescendants(conceptId, result);
			return result;
		}
		
		private function traverseConceptDescendants(conceptId:String, descendantIds:ISet):void {
			descendantIds.add(conceptId);
			for each (var subTypeId:String in getConceptSubTypes(conceptId).toArray()) {
				if (descendantIds.contains(subTypeId)) {
					// TODO: maybe we should check for an illegal cycle?
				}
				else {
					// here's a new one
					traverseConceptDescendants(subTypeId, descendantIds);
				}
			}
		}
		
		private function getConceptSynonymGroupElement(conceptId:String):XML {
			var conceptElements:XMLList = this.referenceXML.synonyms.synonym.concept.(@idRef == conceptId);
			switch (conceptElements.length()) {
				case 0:
					return null;
				case 1:
					return conceptElements[0].parent();
				default:
					throw new Error("Concept exists more than once in synonym groups: " + conceptId);
			}
		}
		
		/**
		 * If the conceptId is in a synonym group, then all concept ids (including self) in that group are returned
		 * If the conceptId is not in any synonym group, then a set containing only that conceptId is returned
		 */
		public function getConceptSynonymsIncludingSelf(conceptId:String):ISet {
			var synonymGroupElement:XML = getConceptSynonymGroupElement(conceptId);
			if (synonymGroupElement == null) {
				var result:ISet = new HashSet();
				result.add(conceptId);
				return result;
			}
			else {
				return XMLUtils.convertToStringISet(synonymGroupElement.concept.@idRef);
			}
		}
		
		public function getCollectedConceptIds(conceptId:String):ISet {
			var result:ISet = new HashSet();
			result.add(conceptId);
			for each (var synonymId:String in getConceptSynonymsIncludingSelf(conceptId).toArray()) {
				result.addAll(getConceptDescendantsAndSelf(synonymId).toArray());
			}
			return result;
		}
		
		private function getConceptIdsStartingWith(prefix:String):ISet {
			var result:ISet = new HashSet();
			for each (var conceptElement:XML in this.referenceXML.concepts.concept.(containsWordPrefixedWith(attribute("id").toString(), prefix))) {
				result.add(conceptElement.@id.toString());				
			}
			for each (conceptElement in this.referenceXML.concepts.concept.concept.(containsWordPrefixedWith(attribute("idRef").toString(), prefix))) {
				result.add(conceptElement.@idRef.toString());				
			}
			for each (conceptElement in this.referenceXML.synonyms.synonym.concept.(containsWordPrefixedWith(attribute("idRef").toString(), prefix))) {
				result.add(conceptElement.@idRef.toString());				
			}
			// also search the tag elements
			var tagElements:XMLList = this.referenceXML.markupCategories.markupCategory.tag.(@type == "concept" && containsWordPrefixedWith(@value, prefix));
			for each (var tagElement:XML in tagElements) {
				var tag:String = tagElement.@value;
				result.add(tag);
			}
			return result;
		}
		
		private static function containsWordPrefixedWith(text:String, prefix:String):Boolean {
			prefix = prefix.toLowerCase();
			var words:Array = text.toLowerCase().split(" ");
			for each (var word:String in words) {
				if (word.indexOf(prefix) == 0) {
					return true;
				}
			}
			return false;
		}
		
		/**
		 * TODO - actually we want to return an ISet but for the moment just a String (type id)
		 * 
		 * For now, If there is no type then return null, otherwise return the first type
		 */ 
		public function getCategoryTypeIdForCategoryId(categoryId:String):String {
			var typeIds:Array = getCategoryTypeIdsForCategoryId(categoryId);
			if (typeIds.length == 0) {
				return null;
			}
			else {
				return typeIds[0];
			}
		}
		
		public function getCategoryTypeIdsForCategoryId(categoryId:String):Array {
			var result:Array = new Array();
			var categoryElement:XML = getCategoryElement(categoryId);
			for each (var tagElement:XML in categoryElement.tag.(@type == "markupType")) {
				result.push(tagElement.@value.toString());
			}
			return result;
		}
		
		public function getCategoryName(categoryId:String):String {
			var categoryElement:XML = getCategoryElement(categoryId);
			return categoryElement.@name.toString();
		}
		
		public function getConceptsForCategoryId(categoryId:String):Array {
			var categoryElement:XML = getCategoryElement(categoryId);			
			var result:Array = new Array();
			for each (var tagElement:XML in categoryElement.tag.(@type == "concept")) {
				result.push(tagElement.@value.toString());
			}
			return result;
		}
		
		public function getExplicitConceptsForMarkupElement1(markupElement:XML):Array {
			var result:Array = new Array();
			for each (var tagElement:XML in markupElement.tag) {
				var tag:String = tagElement.toString();
				if (tag.indexOf(":") < 0) {
					// this tag is for a concept
					if (result.indexOf(tag) < 0) {
						result.push(tag);
					}
				}				
			}
			return result;
		}
		
        public function getCategoryTypeNameFromId(markupTypeId:String):String {
        	return getCategoryTypeElement(markupTypeId).@name.toString();
        }
        
        public function getCategoryTypeIds(allowOutline:Boolean, allowInline:Boolean):Array {
        	var markupTypeElements:XMLList = this.referenceXML.markupTypes.markupType;
        	var result:Array = new Array();
        	for each (var markupTypeElement:XML in markupTypeElements) {
        		if (allowInline && XMLUtils.getAttributeValueAsBoolean(markupTypeElement, "allowInline", false) || allowOutline && XMLUtils.getAttributeValueAsBoolean(markupTypeElement, "allowOutline", false)) {
        			result.push(markupTypeElement.@id.toString());        			
        		}
        	}
        	return result;
        }
        
        private function getCategoryTypeElement(markupTypeId:String):XML {
        	var markupTypeElements:XMLList = this.referenceXML.markupTypes.markupType.(@id == markupTypeId);
        	if (markupTypeElements.length() == 0) {
        		throw new Error("Nothing known about category type: " + markupTypeId);
        	}
			return markupTypeElements[0];        
        }
        
        public function hasCategoryId(categoryId:String):Boolean {
        	return (this.referenceXML.markupCategories.markupCategory.(@id == categoryId) as XMLList).length() > 0;
        }
            	
		public function getCategoryElement(categoryId:String):XML {
			var categoryElements:XMLList = this.referenceXML.markupCategories.markupCategory.(@id == categoryId);
			if (categoryElements.length() == 0) {
				throw new Error("Category id does not exist: " + categoryId);
			} 
			if (categoryElements.length() > 1) {
				throw new Error("More than one category exists with id: " + categoryId);
			}
			return categoryElements[0];
		}
		
		public function editCategory(newName:String, markupTypeIds:Array, concepts:Array, categoryId:String):XML {
			var result:XML;
			if (categoryId == null) {
				categoryId = generateCategoryId(newName);
				result = <markupCategory id={categoryId}/>;
				(this.referenceXML.markupCategories[0] as XML).appendChild(result);
			}
			else {
				result = getCategoryElement(categoryId);
				XMLUtils.removeAllElements(result.*);
			}
			result.@name = newName;
			for each (var typeId:String in markupTypeIds) {
				var tagElement:XML = <tag type="markupType" value={typeId}/>;
				result.appendChild(tagElement);
			}
			for each (var concept:String in concepts) {
				tagElement = <tag type="concept" value={concept}/>;
				result.appendChild(tagElement);
			}
			unsavedChanges = true;
			return result;
		}
		
		/**
		 * TODO - do this properly. Truncate and add postfix etc
		 */
		private function generateCategoryId(categoryName:String):String {
			var nonWordCharPattern:RegExp = /\W+/g;
			var categoryIdBase:String = categoryName.replace(nonWordCharPattern, "-").substr(0, 25).toLowerCase();
			for (var i:int = 1; ; i++) {
				var categoryId:String = categoryIdBase + i;
				if (!hasCategoryId(categoryId)) {
					return categoryId;
				}
			}
			throw new Error("This should not be reachable");
		}
		
		public function getEventTypes():Array {
			var result:Array = [];
			for each (var eventTypeId:String in referenceXML.eventTypes.eventType.@id) {
				result.push(eventTypeId);
			}
			return result;
		}
		
		public function getEventTypeName(eventTypeId:String):String {
			return referenceXML.eventTypes.eventType.(@id == eventTypeId).@name;
		}
		
		public function getLanguages():Array {
			var result:Array = [];
			for each (var id:String in referenceXML.languages.language.@id) {
				result.push(id);
			}
			return result;
		}
		
		public function getCountries():Array {
			var result:Array = [];
			for each (var name:String in referenceXML.places.country.@name) {
				result.push(name);
			}
			return result;
		}
		
		public function getLocations(countryName:String):Array {
			var countryElement:XML = referenceXML.places.country.(@name == countryName)[0];
			var result:Array = [];
			if (countryElement != null) {
				for each (var name:String in countryElement.location.@name) {
					result.push(name);
				}
			}
			return result;
		}

		public function getVenues(countryName:String, locationName:String):Array {
			var locationElement:XML = referenceXML.places.country.(@name == countryName).location.(@name == locationName)[0];
			var result:Array = [];
			if (locationElement != null) {
				for each (var name:String in locationElement.venue.@name) {
					result.push(name);
				}
			}
			return result;
		}
		
		public function addConcept(conceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Adding concept: " + conceptId);
			xqueryExecutor.executeStoredXQuery("update-concept.xql", {newConceptId:conceptId}, function(returnVal:int):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);
		}
		
		public function renameConcept(oldConceptId:String, newConceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Renaming concept: " + oldConceptId + " to: " + newConceptId);
			xqueryExecutor.executeStoredXQuery("update-concept.xql", {oldConceptId:oldConceptId, newConceptId:newConceptId}, function(returnVal:int):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);
		}
		
		public function removeConcept(conceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Removing concept: " + conceptId);
			xqueryExecutor.executeStoredXQuery("update-concept.xql", {oldConceptId:conceptId}, function(returnVal:int):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);
		}
		
		public function addSynonyms(conceptIds:Array, successFunc:Function, failureFunc:Function):void {
			if (conceptIds.length > 2) {
				throw new Error("Adding more than two synonyms at the same time, not yet supported: " + conceptIds);
			}
			trace("Adding synonyms: " + conceptIds);
			var conceptIdsString:String = conceptIds.join(" ");
			xqueryExecutor.executeStoredXQuery("add-synonyms.xql", {conceptIds:conceptIdsString}, function(returnVal:Boolean):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);			
		}

		public function removeSynonym(conceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Removing synonym: " + conceptId);
			xqueryExecutor.executeStoredXQuery("remove-synonym.xql", {conceptId:conceptId}, function(returnVal:Boolean):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);			
		}
		
		public function addSubtype(superConceptId:String, subConceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Adding: " + subConceptId + " as subtype of: " + superConceptId);
			xqueryExecutor.executeStoredXQuery("add-subtype.xql", {superConceptId:superConceptId, subConceptId:subConceptId}, function(returnVal:Boolean):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);			
		}
		
		public function removeSubtype(superConceptId:String, subConceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Removing: " + subConceptId + " as subtype of: " + superConceptId);
			xqueryExecutor.executeStoredXQuery("remove-subtype.xql", {superConceptId:superConceptId, subConceptId:subConceptId}, function(returnVal:Boolean):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);			
		}
		
		public function getAllConcepts(successFunc:Function, failureFunc:Function):void {
			trace("Fetching all concepts");
			xqueryExecutor.executeStoredXQuery("get-all-concepts.xql", {}, function(returnVal:String):void {
				loadReferences(function():void {
					successFunc(returnVal.split(" "));
				}, failureFunc);
			}, failureFunc);			
		}
		
		public function countConceptInstances(conceptId:String, successFunc:Function, failureFunc:Function):void {
			trace("Counting instances of concept: " + conceptId);
			xqueryExecutor.executeStoredXQuery("count-concept-instances.xql", {conceptId:conceptId}, function(returnVal:int):void {
				loadReferences(function():void {
					successFunc(returnVal);
				}, failureFunc);
			}, failureFunc);			
		}
	}
}
		
