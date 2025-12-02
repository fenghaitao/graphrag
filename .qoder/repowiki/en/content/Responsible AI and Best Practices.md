# Responsible AI and Best Practices

<cite>
**Referenced Files in This Document**   
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md)
- [README.md](file://README.md)
- [graph_rag_config.py](file://graphrag/config/models/graph_rag_config.py)
- [language_model_config.py](file://graphrag/config/models/language_model_config.py)
- [input_config.py](file://graphrag/config/models/input_config.py)
- [storage_config.py](file://graphrag/config/models/storage_config.py)
- [community_report.py](file://graphrag/prompts/index/community_report.py)
- [extract_claims.py](file://graphrag/prompts/index/extract_claims.py)
- [global_search_knowledge_system_prompt.py](file://graphrag/prompts/query/global_search_knowledge_system_prompt.py)
- [drift_search_system_prompt.py](file://graphrag/prompts/query/drift_search_system_prompt.py)
- [SECURITY.md](file://SECURITY.md)
- [prompt_tune.py](file://graphrag/api/prompt_tune.py)
- [main.py](file://graphrag/cli/main.py)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Intended Use Cases](#intended-use-cases)
3. [Evaluation Metrics and Performance Measurement](#evaluation-metrics-and-performance-measurement)
4. [Operational Factors for Responsible Use](#operational-factors-for-responsible-use)
5. [Human-in-the-Loop Validation and Domain Expertise](#human-in-the-loop-validation-and-domain-expertise)
6. [Cost Management Strategies](#cost-management-strategies)
7. [Security Considerations](#security-considerations)
8. [Best Practices for Dataset Selection and Configuration](#best-practices-for-dataset-selection-and-configuration)
9. [Result Verification and Hallucination Mitigation](#result-verification-and-hallucination-mitigation)
10. [When Not to Use GraphRAG](#when-not-to-use-graphrag)

## Introduction
GraphRAG is an AI-based content interpretation and search capability that uses Large Language Models (LLMs) to parse data, create knowledge graphs, and answer user questions about private datasets. This document outlines responsible AI practices and best practices for deploying GraphRAG effectively while minimizing risks. The guidance is based on the RAI_TRANSPARENCY.md document and codebase analysis, covering intended use cases, limitations, evaluation metrics, operational factors, security considerations, and best practices for responsible deployment.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L3-L6)
- [README.md](file://README.md#L24-L26)

## Intended Use Cases
GraphRAG is designed for critical information discovery and analysis use cases where insights require connecting information across large volumes of data. It excels in scenarios where information spans multiple documents, is noisy, mixed with misinformation, or when users need to answer abstract or thematic questions that cannot be directly answered from the underlying data.

The system is particularly effective for datasets that are entity-rich, focusing on people, places, organizations, and other uniquely identifiable objects. GraphRAG connects information across documents to answer complex questions that are difficult or impossible to address with traditional keyword or vector-based search mechanisms, such as "What are the top themes in this dataset?" or questions that require synthesizing information from multiple sources.

GraphRAG is intended to be deployed with domain-specific text corpora and is designed for users who are trained in responsible analytic approaches and critical reasoning. While the system can provide high degrees of insight on complex topics, human analysis by domain experts is essential to verify and augment the generated responses.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L7-L15)
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L39-L40)

## Evaluation Metrics and Performance Measurement
GraphRAG has been evaluated across four primary dimensions to ensure responsible AI practices:

1. **Accurate representation of the dataset**: Tested through manual inspection and automated testing against "gold answer" benchmarks created from randomly selected subsets of test corpora. This ensures the system faithfully represents the source data.

2. **Transparency and groundedness of responses**: Evaluated via automated answer coverage assessment and human inspection of the underlying context. The system implements grounding rules that require data references to be explicitly cited in responses, with a limit of five record IDs per reference followed by "+more" when additional references exist.

3. **Resilience to prompt and data corpus injection attacks**: Assessed using manual and semi-automated techniques to test both user prompt injection attacks ("jailbreaks") and cross-prompt injection attacks ("data attacks"). The system is designed to be robust against such attacks while operating in trusted user environments.

4. **Low hallucination rates**: Measured using claim coverage metrics, manual inspection of answers and sources, and adversarial attacks designed to force hallucinations through challenging datasets. The system includes safeguards such as requiring explicit evidence for claims and prohibiting the inclusion of information without supporting evidence.

These evaluation metrics ensure that GraphRAG provides reliable, transparent, and well-grounded responses while minimizing the risk of generating false or misleading information.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L17-L27)
- [community_report.py](file://graphrag/prompts/index/community_report.py#L136-L150)
- [extract_claims.py](file://graphrag/prompts/index/extract_claims.py#L13-L21)

## Operational Factors for Responsible Use
Effective and responsible use of GraphRAG requires attention to several operational factors and settings. The system is designed for users with domain sophistication and experience in handling complex information challenges. While GraphRAG demonstrates robustness against injection attacks and can identify conflicting information sources, it operates best in trusted user environments with proper human oversight.

Key operational considerations include:

- **Domain-specific configuration**: For optimal results, GraphRAG should be configured with domain-specific prompts and entity specifications. While example indexing prompts are provided for general applications, unique datasets may require careful identification of domain-specific concepts for effective indexing.

- **Configuration validation**: The CLI provides a dry-run option (`--dry-run`) that allows users to inspect and validate configurations without executing indexing steps, helping prevent costly mistakes.

- **Resource management**: The system supports concurrent requests and configurable rate limiting strategies to manage API usage and prevent overwhelming LLM services.

- **Model configuration**: Users can configure multiple LLMs with different settings for chat and embedding operations, including retry strategies, rate limiting, and request timeouts to ensure reliable operation.

- **Storage flexibility**: GraphRAG supports various storage types including file, blob, and CosmosDB, allowing organizations to choose the most appropriate storage solution for their security and compliance requirements.

Organizations should ensure that users are trained in critical reasoning and that proper human analysis of responses is conducted to generate reliable insights. The provenance of information should be traced to ensure agreement with the inferences made during answer generation.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L35-L38)
- [graph_rag_config.py](file://graphrag/config/models/graph_rag_config.py#L75-L417)
- [language_model_config.py](file://graphrag/config/models/language_model_config.py#L28-L404)
- [main.py](file://graphrag/cli/main.py#L119-L171)

## Human-in-the-Loop Validation and Domain Expertise
GraphRAG is designed to augment, not replace, human expertise. The system requires domain experts to validate and interpret its outputs, as human analysis is essential for verifying the accuracy and relevance of generated responses. This human-in-the-loop approach ensures that insights are properly contextualized and that potential errors or biases are identified.

The system supports this workflow through several mechanisms:

- **Explicit grounding**: Responses include data references that allow domain experts to trace claims back to their source evidence, facilitating verification.

- **Confidence scoring**: Some search methods include importance scores (0-100) that indicate how well a point addresses the user's question, helping experts prioritize which responses to validate first.

- **Follow-up suggestions**: The DRIFT search method generates follow-up questions that can guide human analysts in exploring topics more deeply.

- **Community reporting**: The system generates community reports with executive summaries, findings, and impact severity ratings that provide structured information for expert review.

Organizations should establish processes for domain experts to review GraphRAG outputs, validate key insights against source materials, and provide feedback to improve the system's performance over time. This collaborative approach between AI and human expertise maximizes the value of the system while minimizing risks associated with automated decision-making.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L14-L15)
- [drift_search_system_prompt.py](file://graphrag/prompts/query/drift_search_system_prompt.py#L68-L73)
- [community_report.py](file://graphrag/prompts/index/community_report.py#L118-L153)

## Cost Management Strategies
Indexing with GraphRAG can be an expensive operation due to the extensive use of LLMs for entity extraction, relationship mapping, and content summarization. To manage costs effectively, organizations should implement the following strategies:

- **Test with small datasets**: Create a small test dataset in the target domain to evaluate indexer performance and quality before committing to large-scale indexing operations.

- **Prompt tuning**: Use the prompt tuning functionality to optimize prompts for the specific domain, which can improve efficiency and reduce the need for multiple indexing iterations.

- **Caching**: Enable LLM caching (`--cache` option) to avoid redundant API calls for identical inputs, significantly reducing costs during development and testing.

- **Configuration optimization**: Adjust parameters such as chunk size, entity extraction thresholds, and community detection settings to balance quality and cost.

- **Incremental indexing**: For evolving datasets, use incremental indexing to update only new or changed content rather than reprocessing the entire dataset.

- **Resource monitoring**: Use the memory profiling option (`--memprofile`) to understand resource usage patterns and optimize accordingly.

The system provides configuration options for rate limiting (requests per minute, tokens per minute) and retry strategies that help manage API costs and prevent excessive usage. Organizations should carefully monitor their LLM provider usage and costs, especially during the initial deployment and tuning phases.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L33-L34)
- [README.md](file://README.md#L36-L37)
- [main.py](file://graphrag/cli/main.py#L167-L170)

## Security Considerations
GraphRAG incorporates several security features and considerations to protect data and ensure responsible deployment:

- **Prompt injection resilience**: The system has been evaluated for resilience against both user prompt injection attacks ("jailbreaks") and cross-prompt injection attacks ("data attacks") using manual and semi-automated techniques.

- **Data privacy**: GraphRAG itself does not collect user data, but users must verify the data privacy policies of their chosen LLM provider. The system supports various storage options, including local file storage, to maintain data within organizational boundaries.

- **Authentication and authorization**: The configuration supports various authentication methods for LLM services, including API keys and Azure Managed Identity, allowing organizations to implement appropriate access controls.

- **Vulnerability reporting**: Microsoft follows the principle of Coordinated Vulnerability Disclosure, with a dedicated process for reporting security issues through the Microsoft Security Response Center.

- **Content safety**: While GraphRAG has been evaluated for resilience to harmful content, the configured LLM may still produce inappropriate or offensive content. Organizations should assess outputs for their specific context and consider implementing additional safety filters, such as Azure AI Content Safety, particularly for sensitive applications.

Organizations should conduct their own security assessments, especially when deploying GraphRAG in regulated environments or with sensitive data. Custom safety solutions may be necessary depending on the specific use case and risk tolerance.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L25-L26)
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L40-L41)
- [SECURITY.md](file://SECURITY.md#L7-L37)
- [language_model_config.py](file://graphrag/config/models/language_model_config.py#L28-L61)

## Best Practices for Dataset Selection and Configuration
To achieve optimal results with GraphRAG, organizations should follow these best practices for dataset selection and system configuration:

- **Select appropriate datasets**: Focus on natural language text data that is collectively focused on a specific topic or theme and is entity-rich. Documents should contain meaningful relationships between people, places, organizations, and other identifiable entities.

- **Use prompt tuning**: Fine-tune prompts for the specific domain using the built-in prompt tuning functionality. This process automatically generates domain-specific prompts for entity extraction, community reporting, and other operations based on sample data.

- **Configure grounding rules**: Ensure that the system's grounding rules are properly configured to require evidence citation and prevent unsupported claims. The default configuration limits references to five record IDs with "+more" for additional sources.

- **Set appropriate thresholds**: Configure thresholds for entity extraction, relationship detection, and community identification based on the characteristics of the dataset and the desired level of granularity.

- **Validate input configuration**: Ensure that input file patterns, encoding, and column specifications are correctly configured to properly ingest the dataset.

- **Choose appropriate storage**: Select the storage type (file, blob, CosmosDB) that best meets the organization's security, compliance, and performance requirements.

- **Configure LLM settings**: Set appropriate parameters for the LLM such as temperature, max_tokens, and response format based on the use case requirements.

The prompt tuning process automatically generates key configuration elements including domain identification, persona generation, community reporter roles, and specialized prompts for entity and community summarization, reducing the need for manual configuration.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L31-L32)
- [prompt_tune.py](file://graphrag/api/prompt_tune.py#L109-L202)
- [input_config.py](file://graphrag/config/models/input_config.py#L14-L51)
- [storage_config.py](file://graphrag/config/models/storage_config.py#L14-L53)

## Result Verification and Hallucination Mitigation
GraphRAG implements several mechanisms to support result verification and mitigate hallucinations:

- **Evidence-based responses**: The system requires that points supported by data include explicit references to source records, with a limit of five record IDs per reference followed by "+more" when additional sources exist.

- **Real-world knowledge annotation**: When incorporating general knowledge beyond the dataset, the system explicitly annotates this with a "[LLM: verify]" tag to distinguish between data-supported claims and external knowledge.

- **Claim status tracking**: For extracted claims, the system tracks status as TRUE, FALSE, or SUSPECTED, providing transparency about the verification level of each claim.

- **Structured output format**: Responses are formatted in JSON with clear separation of description, supporting evidence, and confidence scores, making it easier to verify individual components.

- **Follow-up questioning**: The DRIFT search method generates follow-up questions that can help users explore topics more deeply and verify initial findings.

- **Community report ratings**: The system can generate impact severity ratings for community reports, helping users prioritize which findings to verify first.

Organizations should establish verification workflows where domain experts review key findings, trace claims back to source evidence, and validate the reasoning process. The system's transparency features enable this verification process by providing clear provenance for all generated insights.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L27-L28)
- [global_search_knowledge_system_prompt.py](file://graphrag/prompts/query/global_search_knowledge_system_prompt.py#L6-L9)
- [extract_claims.py](file://graphrag/prompts/index/extract_claims.py#L20-L21)
- [drift_search_system_prompt.py](file://graphrag/prompts/query/drift_search_system_prompt.py#L85-L87)

## When Not to Use GraphRAG
GraphRAG may not be the appropriate solution in the following scenarios:

- **Small, simple datasets**: For datasets with limited documents or straightforward information needs, traditional search methods may be more cost-effective and efficient.

- **Non-textual data**: GraphRAG is designed for natural language text data and may not be suitable for structured data, images, audio, or other non-textual formats without significant preprocessing.

- **Real-time requirements**: The indexing process is relatively expensive and time-consuming, making GraphRAG unsuitable for applications requiring real-time indexing of rapidly changing data.

- **Highly sensitive contexts without additional safeguards**: While GraphRAG has been evaluated for safety, organizations should exercise caution when deploying in highly sensitive contexts without implementing additional safety filters and human oversight mechanisms.

- **Lack of domain expertise**: The system requires domain experts to validate outputs, so it may not be appropriate in organizations without access to subject matter experts.

- **Limited budget for LLM usage**: Organizations with strict budget constraints for LLM API usage should carefully evaluate the costs of indexing and querying before adopting GraphRAG.

In these cases, alternative approaches such as traditional keyword search, vector databases, or simpler NLP techniques may be more appropriate and cost-effective solutions.

**Section sources**
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L33-L34)
- [RAI_TRANSPARENCY.md](file://RAI_TRANSPARENCY.md#L40-L41)
- [README.md](file://README.md#L36-L37)