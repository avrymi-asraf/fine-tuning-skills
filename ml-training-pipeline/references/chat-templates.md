# Chat Templates & Tool Calling

Complete guide to formatting conversations for training.

## Standard Chat Format

HuggingFace standard format for conversations:

```python
messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What's the weather like?"},
    {"role": "assistant", "content": "I don't have access to real-time weather data."}
]
```

Roles: `system`, `user`, `assistant`, `tool`

## Applying Chat Templates

### Basic Usage

```python
text = tokenizer.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=False  # True for inference
)
```

### During Training

```python
def format_dataset(example):
    messages = [
        {"role": "user", "content": example["instruction"]},
        {"role": "assistant", "content": example["output"]}
    ]
    text = tokenizer.apply_chat_template(messages, tokenize=False)
    return {"text": text}

dataset = dataset.map(format_dataset)
```

## Tool Calling Format

### Tool Definition

```python
tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "The city and state, e.g. San Francisco, CA"
                },
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"]
                }
            },
            "required": ["location"]
        }
    }
}]
```

### Tool Use Conversation

```python
messages = [
    {"role": "user", "content": "What's the weather in Paris?"},
    {"role": "assistant", "tool_calls": [{
        "id": "call_123",
        "type": "function",
        "function": {
            "name": "get_weather",
            "arguments": '{"location": "Paris", "unit": "celsius"}'
        }
    }]},
    {"role": "tool", "tool_call_id": "call_123", "content": "22°C and sunny"},
    {"role": "assistant", "content": "The weather in Paris is 22°C and sunny."}
]

text = tokenizer.apply_chat_template(messages, tools=tools, tokenize=False)
```

## Model-Specific Templates

### Llama 2/3

```python
# Llama 2
messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"},
    {"role": "assistant", "content": "Hi there! How can I help?"}
]
# Produces:
# <<sYS>>
# You are a helpful assistant.
# <</SYS>>
# Hello! [/INST] Hi there! How can I help? </s>

# Llama 3
# <|begin_of_text|><|start_header_id|>system<|end_header_id|>
# You are a helpful assistant.
# <|eot_id|><|start_header_id|>user<|end_header_id|>
# Hello!
# <|eot_id|><|start_header_id|>assistant<|end_header_id|>
# Hi there! How can I help?
# <|eot_id|>
```

### Mistral

```python
# <s>[INST] You are a helpful assistant. [/INST]
# [INST] Hello! [/INST] Hi there! How can I help?
```

### Qwen

```python
# <|im_start|>system
# You are a helpful assistant.
# <|im_end|>
# <|im_start|>user
# Hello!
# <|im_end|>
# <|im_start|>assistant
# Hi there! How can I help?
# <|im_end|>
```

### ChatGLM

```python
# [gMASK]sop<|system|>
# You are a helpful assistant.
# <|user|>
# Hello!
# <|assistant|>
# Hi there! How can I help?
```

## Custom Chat Template

If a model lacks a chat template, you can add one:

```python
template = """{% for message in messages %}
{% if message['role'] == 'system' %}
System: {{ message['content'] }}
{% elif message['role'] == 'user' %}
User: {{ message['content'] }}
{% elif message['role'] == 'assistant' %}
Assistant: {{ message['content'] }}
{% endif %}
{% endfor %}"""

tokenizer.chat_template = template
```

## Training with Tool Calling

### Dataset Format

```json
{
  "messages": [
    {"role": "user", "content": "Calculate 2+2"},
    {"role": "assistant", "tool_calls": [{
      "function": {"name": "calculator", "arguments": "{\"expression\": \"2+2\"}"}
    }]},
    {"role": "tool", "content": "4"},
    {"role": "assistant", "content": "The result is 4."}
  ],
  "tools": [{
    "type": "function",
    "function": {
      "name": "calculator",
      "description": "Performs calculations",
      "parameters": {...}
    }
  }]
}
```

### Processing Script

```python
def prepare_tool_calling_data(example, tokenizer):
    messages = example["messages"]
    tools = example.get("tools", [])

    # Format with tools
    text = tokenizer.apply_chat_template(
        messages,
        tools=tools,
        tokenize=False
    )

    return {"text": text}
```

## Masking in Training

Train only on assistant responses:

```python
from trl import DataCollatorForCompletionOnlyLM

response_template = "\n### Assistant:\n"  # Match your template
collator = DataCollatorForCompletionOnlyLM(
    response_template=response_template,
    tokenizer=tokenizer,
    mlm=False
)
```

## Multi-Turn Conversations

```python
messages = [
    {"role": "system", "content": "You are a helpful coding assistant."},
    {"role": "user", "content": "How do I reverse a list in Python?"},
    {"role": "assistant", "content": "You can use list[::-1] or list.reverse()."},
    {"role": "user", "content": "What about a string?"},
    {"role": "assistant", "content": "Strings also support slicing: string[::-1]"}
]
```

## Best Practices

1. **Always use the model's native template** - Don't reinvent formatting
2. **Include system prompt consistently** - Or use empty string for default
3. **Handle special tokens correctly** - Check tokenizer special tokens
4. **Test formatting before training** - Verify output looks correct
5. **Use `add_generation_prompt=True` only for inference** - Not training
