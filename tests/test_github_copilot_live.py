#!/usr/bin/env python3
"""
Integration test for GitHub Copilot with GraphRAG.

This script tests the actual integration with GitHub Copilot models,
verifying that headers are correctly set and authentication works.

Run this script inside VS Code with GitHub Copilot enabled.
"""

import asyncio
import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from graphrag.config.models.language_model_config import LanguageModelConfig
from graphrag.config.enums import ModelType
from graphrag.language_model.providers.litellm.chat_model import LitellmChatModel
from graphrag.language_model.providers.litellm.embedding_model import (
    LitellmEmbeddingModel,
)


async def test_chat_model():
    """Test GitHub Copilot chat model."""
    print("\n" + "=" * 60)
    print("Testing GitHub Copilot Chat Model")
    print("=" * 60)
    
    try:
        # Create configuration
        config = LanguageModelConfig(
            type=ModelType.Chat,
            model_provider="github_copilot",
            model="gpt-4o-mini",  # Use mini for faster/cheaper testing
            api_key="copilot",  # Placeholder - OAuth2 handled by LiteLLM via VS Code
            retry_strategy="exponential_backoff",
            max_retries=3,
            temperature=0.7,
        )
        
        print(f"✓ Configuration created")
        print(f"  Model: {config.model_provider}/{config.model}")
        print(f"  Auth: {config.api_key}")
        
        # Create model instance
        model = LitellmChatModel(
            name="test_chat",
            config=config,
            cache=None,
        )
        
        print(f"✓ Model instance created")
        
        # Test simple completion
        print(f"\n📤 Testing chat completion...")
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Say 'Hello from GitHub Copilot!' and nothing else."},
        ]
        
        response = await model.acompletion(messages=messages)
        
        print(f"✓ Completion successful")
        print(f"\n📨 Response:")
        if hasattr(response, 'choices') and response.choices:
            content = response.choices[0].message.content
            print(f"  {content}")
        else:
            print(f"  {response}")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Chat model test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


async def test_embedding_model():
    """Test GitHub Copilot embedding model."""
    print("\n" + "=" * 60)
    print("Testing GitHub Copilot Embedding Model")
    print("=" * 60)
    
    try:
        # Create configuration
        config = LanguageModelConfig(
            type=ModelType.Embedding,
            model_provider="github_copilot",
            model="text-embedding-3-small",
            api_key="copilot",  # Placeholder - OAuth2 handled by LiteLLM via VS Code
            retry_strategy="exponential_backoff",
            max_retries=3,
        )
        
        print(f"✓ Configuration created")
        print(f"  Model: {config.model_provider}/{config.model}")
        print(f"  Auth: {config.api_key}")
        
        # Create model instance
        model = LitellmEmbeddingModel(
            name="test_embedding",
            config=config,
            cache=None,
        )
        
        print(f"✓ Model instance created")
        
        # Test single embedding
        print(f"\n📤 Testing single embedding...")
        text = "Hello from GitHub Copilot!"
        
        embedding = await model.aembed(text)
        
        print(f"✓ Embedding successful")
        print(f"  Embedding dimension: {len(embedding)}")
        print(f"  First 5 values: {embedding[:5]}")
        
        # Test batch embedding
        print(f"\n📤 Testing batch embedding...")
        texts = [
            "First test text",
            "Second test text",
            "Third test text",
        ]
        
        embeddings = await model.aembed_batch(texts)
        
        print(f"✓ Batch embedding successful")
        print(f"  Number of embeddings: {len(embeddings)}")
        print(f"  Embedding dimension: {len(embeddings[0])}")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Embedding model test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


async def test_headers_injection():
    """Test that headers are properly injected."""
    print("\n" + "=" * 60)
    print("Testing Header Injection")
    print("=" * 60)
    
    try:
        import litellm
        
        # Check environment variable
        if "LITELLM_EXTRA_HEADERS" in os.environ:
            print(f"✓ LITELLM_EXTRA_HEADERS environment variable set")
            print(f"  Value: {os.environ['LITELLM_EXTRA_HEADERS']}")
        else:
            print(f"⚠️  LITELLM_EXTRA_HEADERS not set in environment")
        
        # Check litellm module attributes
        if hasattr(litellm, "extra_headers"):
            print(f"✓ litellm.extra_headers configured")
            print(f"  Headers: {litellm.extra_headers}")
            
            # Verify required headers
            required_headers = ["Editor-Version", "Copilot-Integration-Id"]
            for header in required_headers:
                if header in litellm.extra_headers:
                    print(f"  ✓ {header}: {litellm.extra_headers[header]}")
                else:
                    print(f"  ✗ {header}: NOT FOUND")
                    return False
        else:
            print(f"⚠️  litellm.extra_headers not configured")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Header injection test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


async def main():
    """Run all integration tests."""
    print("\n🧪 GitHub Copilot Integration Tests")
    print("=" * 60)
    print("⚠️  Make sure you're running this in VS Code with GitHub Copilot enabled!")
    print("=" * 60)
    
    results = {
        "Headers": await test_headers_injection(),
        "Chat Model": await test_chat_model(),
        "Embedding Model": await test_embedding_model(),
    }
    
    # Print summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    all_passed = True
    for test_name, result in results.items():
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name}: {status}")
        if not result:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed!")
        print("\nTroubleshooting:")
        print("1. Make sure you're running in VS Code with GitHub Copilot")
        print("2. Check that GitHub Copilot extension is active")
        print("3. Verify your GitHub Copilot subscription is active")
        print("4. Try restarting VS Code")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
