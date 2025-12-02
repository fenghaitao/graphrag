# Data Models and Schemas

<cite>
**Referenced Files in This Document**   
- [entity.py](file://graphrag/data_model/entity.py)
- [relationship.py](file://graphrag/data_model/relationship.py)
- [community.py](file://graphrag/data_model/community.py)
- [community_report.py](file://graphrag/data_model/community_report.py)
- [text_unit.py](file://graphrag/data_model/text_unit.py)
- [covariate.py](file://graphrag/data_model/covariate.py)
- [document.py](file://graphrag/data_model/document.py)
- [named.py](file://graphrag/data_model/named.py)
- [identified.py](file://graphrag/data_model/identified.py)
- [schemas.py](file://graphrag/data_model/schemas.py)
- [types.py](file://graphrag/data_model/types.py)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Core Data Models](#core-data-models)
3. [Model Relationships](#model-relationships)
4. [Serialization and JSON Representation](#serialization-and-json-representation)
5. [Pydantic-based Validation and Schema Generation](#pydantic-based-validation-and-schema-generation)
6. [Storage Persistence](#storage-persistence)
7. [API Exposure](#api-exposure)
8. [Usage in Pipeline](#usage-in-pipeline)
9. [Conclusion](#conclusion)

## Introduction

The GraphRAG data model defines a comprehensive knowledge graph structure for representing and analyzing unstructured text data. This documentation provides a definitive reference for the core entities in the `data_model` module, detailing their fields, types, constraints, and semantic meanings. The model supports complex relationships between entities, hierarchical community structures, and rich metadata through covariates. These data structures form the foundation of the GraphRAG pipeline, enabling sophisticated graph-based retrieval augmented generation (RAG) capabilities.

**Section sources**
- [entity.py](file://graphrag/data_model/entity.py#L1-L70)
- [relationship.py](file://graphrag/data_model/relationship.py#L1-L66)
- [community.py](file://graphrag/data_model/community.py#L1-L80)

## Core Data Models

### Entity

The `Entity` class represents a named entity extracted from text, serving as a fundamental node in the knowledge graph.

**Fields:**
- `id`: Unique identifier for the entity
- `title`: Name/title of the entity
- `short_id`: Human-readable ID for user-facing contexts
- `type`: Category or classification of the entity (optional)
- `description`: Natural language description of the entity (optional)
- `description_embedding`: Semantic embedding of the description (optional)
- `name_embedding`: Semantic embedding of the entity name (optional)
- `community_ids`: List of community IDs to which the entity belongs (optional)
- `text_unit_ids`: List of text unit IDs where the entity appears (optional)
- `rank`: Importance ranking of the entity (default: 1)
- `attributes`: Additional metadata associated with the entity (optional)

The Entity class inherits from `Named`, which provides the basic identification and naming capabilities. Entities are central to the knowledge graph, representing people, organizations, locations, or other significant concepts mentioned in the source documents.

**Section sources**
- [entity.py](file://graphrag/data_model/entity.py#L1-L70)

### Relationship

The `Relationship` class represents connections between entities, forming the edges of the knowledge graph.

**Fields:**
- `id`: Unique identifier for the relationship
- `short_id`: Human-readable ID for user-facing contexts
- `source`: Name of the source entity
- `target`: Name of the target entity
- `weight`: Strength or confidence of the relationship (default: 1.0)
- `description`: Natural language description of the relationship (optional)
- `description_embedding`: Semantic embedding of the relationship description (optional)
- `text_unit_ids`: List of text unit IDs where the relationship is mentioned (optional)
- `rank`: Importance ranking of the relationship (default: 1)
- `attributes`: Additional metadata associated with the relationship (optional)

Relationships capture how entities interact or are connected within the text. They can represent various types of associations such as "works for", "located in", or "collaborates with". The weight field indicates the strength or confidence of the relationship, while the rank field helps prioritize more significant relationships during retrieval.

**Section sources**
- [relationship.py](file://graphrag/data_model/relationship.py#L1-L66)

### Community

The `Community` class represents a cluster of related entities and relationships, forming a hierarchical structure within the knowledge graph.

**Fields:**
- `id`: Unique identifier for the community
- `title`: Name/title of the community
- `short_id`: Human-readable ID for user-facing contexts
- `level`: Hierarchical level of the community
- `parent`: ID of the parent community
- `children`: List of child community IDs
- `entity_ids`: List of entity IDs belonging to the community (optional)
- `relationship_ids`: List of relationship IDs belonging to the community (optional)
- `text_unit_ids`: List of text unit IDs related to the community (optional)
- `covariate_ids`: Dictionary mapping covariate types to their IDs (optional)
- `attributes`: Additional metadata associated with the community (optional)
- `size`: Number of text units in the community (optional)
- `period`: Temporal period associated with the community (optional)

Communities are created through graph clustering algorithms and represent coherent topics or themes within the knowledge graph. The hierarchical structure allows for multi-level analysis, from broad topics at higher levels to more specific subtopics at lower levels.

**Section sources**
- [community.py](file://graphrag/data_model/community.py#L1-L80)

### CommunityReport

The `CommunityReport` class contains LLM-generated summaries of communities, providing natural language insights about the content.

**Fields:**
- `id`: Unique identifier for the report
- `title`: Name/title of the report
- `short_id`: Human-readable ID for user-facing contexts
- `community_id`: ID of the associated community
- `summary`: Brief summary of the community content
- `full_content`: Comprehensive report content
- `rank`: Importance ranking of the report (default: 1.0)
- `full_content_embedding`: Semantic embedding of the full report (optional)
- `attributes`: Additional metadata associated with the report (optional)
- `size`: Number of text units in the report (optional)
- `period`: Temporal period associated with the report (optional)

Community reports transform the structural information of communities into human-readable narratives, making it easier for users to understand the key insights from the knowledge graph without examining individual entities and relationships.

**Section sources**
- [community_report.py](file://graphrag/data_model/community_report.py#L1-L68)

### TextUnit

The `TextUnit` class represents a chunk of text from the original documents, serving as the atomic unit of analysis.

**Fields:**
- `id`: Unique identifier for the text unit
- `short_id`: Human-readable ID for user-facing contexts
- `text`: The actual text content
- `entity_ids`: List of entity IDs mentioned in the text unit (optional)
- `relationship_ids`: List of relationship IDs mentioned in the text unit (optional)
- `covariate_ids`: Dictionary mapping covariate types to their IDs (optional)
- `n_tokens`: Number of tokens in the text (optional)
- `document_ids`: List of document IDs containing this text unit (optional)
- `attributes`: Additional metadata associated with the text unit (optional)

Text units are created by chunking the original documents into manageable segments for processing. They maintain connections to the entities, relationships, and covariates extracted from their content, enabling traceability back to the source text.

**Section sources**
- [text_unit.py](file://graphrag/data_model/text_unit.py#L1-L63)

### Covariate

The `Covariate` class represents additional metadata or claims associated with a subject entity.

**Fields:**
- `id`: Unique identifier for the covariate
- `short_id`: Human-readable ID for user-facing contexts
- `subject_id`: ID of the subject entity
- `subject_type`: Type of the subject (default: "entity")
- `covariate_type`: Type of the covariate (default: "claim")
- `text_unit_ids`: List of text unit IDs where the covariate information appears (optional)
- `attributes`: Additional metadata associated with the covariate

Covariates extend the basic entity-relationship model by capturing structured information about entities, such as claims, attributes, or events. For example, a covariate might represent a claim that "Company X reported $1M revenue in Q1 2023" with the subject being "Company X".

**Section sources**
- [covariate.py](file://graphrag/data_model/covariate.py#L1-L55)

### Document

The `Document` class represents the original source documents that were processed to create the knowledge graph.

**Fields:**
- `id`: Unique identifier for the document
- `title`: Name/title of the document
- `short_id`: Human-readable ID for user-facing contexts
- `type`: Document type (default: "text")
- `text_unit_ids`: List of text unit IDs that comprise the document
- `text`: Raw text content of the document
- `attributes`: Structured metadata such as author, date, etc. (optional)

Documents represent the original input sources and maintain connections to their constituent text units, enabling溯源 and context preservation throughout the analysis pipeline.

**Section sources**
- [document.py](file://graphrag/data_model/document.py#L1-L50)

## Model Relationships

The GraphRAG data models form a richly interconnected knowledge graph with well-defined relationships between entities.

```mermaid
erDiagram
ENTITY {
string id PK
string title
string type
string description
list[float] description_embedding
list[float] name_embedding
list[string] community_ids
list[string] text_unit_ids
int rank
dict[string,Any] attributes
}
RELATIONSHIP {
string id PK
string source
string target
float weight
string description
list[float] description_embedding
list[string] text_unit_ids
int rank
dict[string,Any] attributes
}
COMMUNITY {
string id PK
string title
string level
string parent
list[string] children
list[string] entity_ids
list[string] relationship_ids
list[string] text_unit_ids
dict[string,list[string]] covariate_ids
dict[string,Any] attributes
int size
string period
}
COMMUNITY_REPORT {
string id PK
string community_id
string summary
string full_content
float rank
list[float] full_content_embedding
dict[string,Any] attributes
int size
string period
}
TEXT_UNIT {
string id PK
string text
list[string] entity_ids
list[string] relationship_ids
dict[string,list[string]] covariate_ids
int n_tokens
list[string] document_ids
dict[string,Any] attributes
}
COVARIATE {
string id PK
string subject_id
string subject_type
string covariate_type
list[string] text_unit_ids
dict[string,Any] attributes
}
DOCUMENT {
string id PK
string type
list[string] text_unit_ids
string text
dict[string,Any] attributes
}
ENTITY ||--o{ TEXT_UNIT : "appears_in"
RELATIONSHIP ||--o{ TEXT_UNIT : "mentioned_in"
COVARIATE ||--o{ TEXT_UNIT : "appears_in"
DOCUMENT ||--o{ TEXT_UNIT : "contains"
COMMUNITY ||--o{ ENTITY : "contains"
COMMUNITY ||--o{ RELATIONSHIP : "contains"
COMMUNITY ||--o{ TEXT_UNIT : "contains"
COMMUNITY ||--o{ COVARIATE : "contains"
COMMUNITY_REPORT ||--|| COMMUNITY : "summarizes"
COMMUNITY }o--o{ COMMUNITY : "hierarchical_structure"
COVARIATE ||--|| ENTITY : "describes"
```

**Diagram sources**
- [entity.py](file://graphrag/data_model/entity.py#L1-L70)
- [relationship.py](file://graphrag/data_model/relationship.py#L1-L66)
- [community.py](file://graphrag/data_model/community.py#L1-L80)
- [community_report.py](file://graphrag/data_model/community_report.py#L1-L68)
- [text_unit.py](file://graphrag/data_model/text_unit.py#L1-L63)
- [covariate.py](file://graphrag/data_model/covariate.py#L1-L55)
- [document.py](file://graphrag/data_model/document.py#L1-L50)

## Serialization and JSON Representation

The data models support serialization through their `from_dict` class methods, enabling conversion between Python objects and dictionary representations. This facilitates JSON serialization for storage and transmission.

**Example JSON representations:**

**Entity:**
```json
{
  "id": "ent-001",
  "human_readable_id": "Microsoft",
  "title": "Microsoft",
  "type": "Organization",
  "description": "American multinational technology company",
  "text_unit_ids": ["txt-001", "txt-005"],
  "degree": 15,
  "attributes": {
    "founded": "1975",
    "headquarters": "Redmond, WA"
  }
}
```

**Relationship:**
```json
{
  "id": "rel-001",
  "human_readable_id": "Satya_Nadella_works_for_Microsoft",
  "source": "Satya Nadella",
  "target": "Microsoft",
  "weight": 0.95,
  "description": "CEO of Microsoft Corporation",
  "text_unit_ids": ["txt-001"],
  "rank": 8
}
```

**Community:**
```json
{
  "id": "com-001",
  "human_readable_id": "Cloud_Computing",
  "title": "Cloud Computing",
  "level": "1",
  "parent": null,
  "children": ["com-002", "com-003"],
  "entity_ids": ["ent-001", "ent-002"],
  "relationship_ids": ["rel-001", "rel-002"],
  "text_unit_ids": ["txt-001", "txt-002", "txt-003"],
  "size": 150
}
```

These JSON representations follow the field naming conventions defined in `schemas.py`, using snake_case for field names and including both the technical IDs and human-readable identifiers.

**Section sources**
- [entity.py](file://graphrag/data_model/entity.py#L40-L69)
- [relationship.py](file://graphrag/data_model/relationship.py#L40-L65)
- [community.py](file://graphrag/data_model/community.py#L47-L79)

## Pydantic-based Validation and Schema Generation

While the current implementation uses dataclasses, the field naming conventions and structure are designed to be compatible with Pydantic validation. The `schemas.py` module defines standardized field names and column ordering for data persistence.

**Key schema definitions:**

- **ENTITIES_FINAL_COLUMNS**: Defines the final column order for entity data persistence
- **RELATIONSHIPS_FINAL_COLUMNS**: Defines the final column order for relationship data persistence  
- **COMMUNITIES_FINAL_COLUMNS**: Defines the final column order for community data persistence
- **COMMUNITY_REPORTS_FINAL_COLUMNS**: Defines the final column order for community report data persistence
- **COVARIATES_FINAL_COLUMNS**: Defines the final column order for covariate data persistence
- **TEXT_UNITS_FINAL_COLUMNS**: Defines the final column order for text unit data persistence
- **DOCUMENTS_FINAL_COLUMNS**: Defines the final column order for document data persistence

The schema system ensures consistency across different stages of the pipeline and between memory representations and persistent storage. Field names are defined as constants (e.g., `ID`, `SHORT_ID`, `TITLE`) to prevent typos and ensure uniformity.

The data models support flexible field mapping through their `from_dict` methods, which accept customizable key parameters. This allows the models to adapt to different input formats while maintaining internal consistency.

**Section sources**
- [schemas.py](file://graphrag/data_model/schemas.py#L1-L164)

## Storage Persistence

The data models are persisted using a columnar storage format, typically Parquet files, with the schema definitions in `schemas.py` guiding the column structure and ordering.

Each model type is stored in its own file with the following naming convention:
- `create_final_entities.parquet` - Entity data
- `create_final_relationships.parquet` - Relationship data  
- `create_final_communities.parquet` - Community data
- `create_final_community_reports.parquet` - Community report data
- `create_final_text_units.parquet` - Text unit data
- `create_final_covariates.parquet` - Covariate data
- `create_final_documents.parquet` - Document data

The storage system uses the `ENTITIES_FINAL_COLUMNS`, `RELATIONSHIPS_FINAL_COLUMNS`, and other column ordering constants to ensure consistent schema across runs. This structured approach enables efficient querying and analysis of the knowledge graph components.

The persistence layer maintains referential integrity through ID-based relationships rather than foreign keys, allowing for flexible querying and analysis patterns. The human-readable IDs (short_id) are preserved to facilitate debugging and user-facing applications.

**Section sources**
- [schemas.py](file://graphrag/data_model/schemas.py#L72-L163)

## API Exposure

The data models are exposed through the GraphRAG API, enabling programmatic access to the knowledge graph components.

The API provides endpoints for:
- Querying entities, relationships, communities, and other models
- Retrieving community reports and their associated context
- Accessing text units and their connections to other entities
- Searching for covariates and claims about specific subjects
- Navigating the hierarchical community structure

The API responses follow the JSON serialization format described earlier, with consistent field naming and structure. This enables clients to reliably parse and process the returned data.

The query system uses the data models to build context for retrieval-augmented generation, combining information from multiple models to create comprehensive responses to user queries. For example, a local search might retrieve relevant entities, their relationships, and associated text units to provide detailed answers.

**Section sources**
- [api/query.py](file://graphrag/api/query.py#L75-L721)
- [api/index.py](file://graphrag/api/index.py#L34-L50)

## Usage in Pipeline

The data models are integral to the GraphRAG pipeline, serving as the primary data structures that flow through each processing stage.

**Pipeline stages and model usage:**

1. **Input Processing**: Documents are chunked into TextUnits
2. **Entity Extraction**: Entities and Relationships are identified in TextUnits
3. **Community Detection**: Entities and Relationships are clustered into Communities
4. **Report Generation**: CommunityReports are created for each Community
5. **Covariate Extraction**: Additional metadata (Covariates) is extracted about entities
6. **Indexing**: All models are indexed for efficient retrieval
7. **Query Processing**: Models are retrieved and combined to answer user queries

The models are passed between pipeline components using their dictionary representations, with the `from_dict` methods used to reconstruct the objects as needed. This approach balances memory efficiency with type safety.

The hierarchical nature of the models enables multi-granularity analysis, from detailed text unit examination to high-level community overview. The ranking fields (rank, degree) allow for prioritization of the most significant elements during retrieval.

**Section sources**
- [workflows/create_final_entities.py](file://graphrag/index/workflows/create_final_entities.py)
- [workflows/create_final_relationships.py](file://graphrag/index/workflows/create_final_relationships.py)
- [workflows/create_community_reports.py](file://graphrag/index/workflows/create_community_reports.py)

## Conclusion

The GraphRAG data models provide a comprehensive framework for representing knowledge extracted from unstructured text. By combining entities, relationships, communities, and rich metadata through covariates, the models capture both the structural and semantic aspects of the source content.

The design emphasizes flexibility through optional fields and extensible attributes, while maintaining consistency through standardized field naming and serialization patterns. The hierarchical community structure enables multi-level analysis, from detailed entity relationships to thematic overviews.

For developers working with GraphRAG, understanding these data models is essential for effective querying, extension, and integration with external systems. The models serve as the foundation for all downstream applications, from simple information retrieval to complex analytical workflows.