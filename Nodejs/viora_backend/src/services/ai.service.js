
const { t } = require('../locales');

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = process.env.GROQ_MODEL || 'qwen/qwen3.8-27b';


const FALLBACK_MODELS = [
  'llama-3.3-70b-versatile',
  'qwen/qwen3-32b',
  'llama-3.1-8b-instant',
];

function stripThinkingTags(text) {
  if (!text || typeof text !== 'string') return '';
  return text.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
}

function isConfigured() {
  const apiKey = process.env.GROQ_API_KEY;
  return !!(apiKey && apiKey.trim().length > 0);
}


async function callGroq({ messages, maxTokens = 300, temperature = 0.3, model = DEFAULT_MODEL }) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new Error('GROQ_API_KEY is not configured in environment (.env)');
  }

  const candidateModels = [model, ...FALLBACK_MODELS.filter(m => m && m !== model)];
  let lastError = null;

  for (const candidateModel of candidateModels) {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey.trim()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: candidateModel,
        messages: messages,
        max_tokens: maxTokens,
        temperature: temperature,
        top_p: 0.9,
      }),
    });

    if (response.ok) {
      const data = await response.json();
      const rawReply = data?.choices?.[0]?.message?.content || '';
      const cleaned = stripThinkingTags(rawReply);
      return cleaned || rawReply.trim();
    }

    const errorText = await response.text();
    lastError = new Error(`Groq API Error (${candidateModel}): ${response.status} - ${errorText}`);
    const lowerErr = errorText.toLowerCase();
    const isModelIssue = response.status === 404 ||
      (response.status === 400 && (lowerErr.includes('model') || lowerErr.includes('decommissioned')));
    if (!isModelIssue) {
      console.error('[Groq AI Error]:', response.status, errorText);
      throw lastError;
    }
    console.warn(`[Groq AI] Model ${candidateModel} unavailable, trying fallback...`);
  }

  throw lastError || new Error('Groq API call failed');
}

async function summarizeMessages({ messages = [], language = 'vi' }) {
  if (!Array.isArray(messages) || messages.length === 0) {
    return t(language, 'ai.noMessages');
  }

  const defaultMember = t(language, 'ai.member');

  const cleanList = messages
    .slice(-50)
    .filter(m => {
      const text = (m.content || m.text || '').trim();
      return text.length > 1;
    })
    .map(m => {
      const sender = m.senderName || m.sender?.username || defaultMember;
      const time = m.time || '';
      const text = (m.content || m.text || '').trim();
      return time ? `[${time}] ${sender}: ${text}` : `${sender}: ${text}`;
    });

  if (cleanList.length === 0) {
    return t(language, 'ai.noMeaningfulMessages');
  }

  const chatContent = cleanList.join('\n');
  const systemPrompt = t(language, 'ai.summarizeSystemPrompt');
  const userPrompt = t(language, 'ai.summarizeUserPrompt', { content: chatContent });

  return await callGroq({
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
    maxTokens: 350,
    temperature: 0.2,
  });
}

async function chatWithVioraAI({ userMessage = '', userName = '', history = [], language = 'vi' }) {
  if (!userMessage || !userMessage.trim()) return '';

  const effectiveUserName = (userName && userName.trim())
    ? userName.trim()
    : t(language, 'ai.defaultUserTitle');

  const systemPrompt = t(language, 'ai.chatSystemPrompt', { userName: effectiveUserName });

  const messagesPayload = [
    { role: 'system', content: systemPrompt },
  ];

  if (Array.isArray(history) && history.length > 0) {
    const recentHistory = history.slice(-6);
    for (const h of recentHistory) {
      if (h.sender === 'ai' || h.isAi) {
        messagesPayload.push({ role: 'assistant', content: h.text || h.content || '' });
      } else {
        messagesPayload.push({ role: 'user', content: h.text || h.content || '' });
      }
    }
  }

  messagesPayload.push({ role: 'user', content: userMessage.trim() });

  return await callGroq({
    messages: messagesPayload,
    maxTokens: 180,
    temperature: 0.7,
  });
}

async function explainTermInContext({ term, chatSnippet = '', language = 'vi' }) {
  const systemPrompt = t(language, 'ai.explainSystemPrompt');
  const userPrompt = t(language, 'ai.explainUserPrompt', { term, chatSnippet });

  return await callGroq({
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
    maxTokens: 250,
    temperature: 0.3,
  });
}

const LANGUAGE_MAP = {
  vi: 'Vietnamese',
  en: 'English',
  ko: 'Korean',
  ja: 'Japanese',
  zh: 'Chinese',
  fr: 'French',
  de: 'German',
  es: 'Spanish',
  ru: 'Russian',
  th: 'Thai',
  id: 'Indonesian',
  pt: 'Portuguese',
  it: 'Italian',
  nl: 'Dutch',
  sv: 'Swedish',
  no: 'Norwegian',
  da: 'Danish',
  fi: 'Finnish',
  pl: 'Polish',
  cs: 'Czech',
  el: 'Greek',
  tr: 'Turkish',
  ar: 'Arabic',
  hi: 'Hindi',
  bn: 'Bengali',
  ms: 'Malay',
  tl: 'Filipino',
  uk: 'Ukrainian',
  he: 'Hebrew',
  fa: 'Persian',
};

async function translateText(textOrOptions, maybeTargetLang = 'vi') {
  let text = textOrOptions;
  let targetLang = maybeTargetLang;

  if (typeof textOrOptions === 'object' && textOrOptions !== null) {
    text = textOrOptions.text;
    targetLang = textOrOptions.targetLang || maybeTargetLang || 'vi';
  }

  if (!text || !text.trim()) return '';

  const cleanText = text.trim();
  const targetName = LANGUAGE_MAP[targetLang?.toLowerCase()] || targetLang || 'Vietnamese';

  const systemPrompt = [
    `You are a professional, accurate translator for a social network chat application.`,
    `Task: Translate the given message into ${targetName}.`,
    `Rules:`,
      `- Preserve the original tone (casual, polite, humorous, etc.), emojis, and chat context.`,
      `- Translate slang, idioms, and internet jargon naturally into equivalent expressions in ${targetName}.`,
      `- Output ONLY the translated text. Do NOT add quotation marks, greetings, explanations, notes, or any prefix/suffix.`
  ].join('\n');

  return await callGroq({
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: cleanText }
    ],
    maxTokens: 500,
    temperature: 0.2,
  });
}

async function replyAsThirdPartyParticipant({
  promptText = '',
  senderName = '',
  otherParticipantNames = [],
  isGroup = false,
  groupName = '',
  history = [],
  language = 'vi',
}) {
  const isEn = language === 'en';
  const cleanSpeaker = (senderName && senderName.trim()) ? senderName.trim() : (isEn ? 'friend' : 'bạn');
  const othersStr = Array.isArray(otherParticipantNames) && otherParticipantNames.length > 0
    ? otherParticipantNames.filter(Boolean).join(', ')
    : (isEn ? 'another user' : 'người còn lại');

  const chatSettingDesc = isGroup
    ? (isEn
        ? `This is a group chat named "${groupName || 'Group'}". Participants include ${cleanSpeaker} and others (${othersStr}).`
        : `Đây là cuộc trò chuyện nhóm "${groupName || 'Nhóm'}". Thành viên gồm ${cleanSpeaker} và những người khác (${othersStr}).`)
    : (isEn
        ? `This is a 1-on-1 chat between ${cleanSpeaker} and ${othersStr}, and you are participating right inside this chat as a helpful, natural 3rd person.`
        : `Đây là cuộc trò chuyện riêng giữa ${cleanSpeaker} và ${othersStr}. Bạn tham gia ngay trong đoạn chat này như một người thứ 3 thông minh, thân thiện và tự nhiên.`);

  const systemPrompt = isEn
    ? [
        'You are VioraAI, a smart, warm, helpful AI participating as a 3rd participant inside a live chat on Viora.',
        chatSettingDesc,
        'Rules:',
        `- ${cleanSpeaker} just mentioned @VioraAI in the chat. Reply naturally directly to what they asked or discussed, using recent chat context if relevant.`,
        '- Be concise (2-5 sentences unless a detailed explanation or list is genuinely needed).',
        '- Match the tone of the conversation; stay helpful, clear, and polite.',
        '- Do NOT start your message with "VioraAI:". Do NOT invent facts outside the chat context.',
        '- Respond strictly in English.',
      ].join('\n')
    : [
        'Bạn là VioraAI, trợ lý AI thông minh và thân thiện, đang tham gia như người thứ 3 ngay trong cuộc trò chuyện trên Viora.',
        chatSettingDesc,
        'Quy tắc:',
        `- ${cleanSpeaker} vừa nhắc @VioraAI trong đoạn chat. Hãy trả lời đúng trọng tâm điều ${cleanSpeaker} hỏi hoặc bàn luận, dựa theo ngữ cảnh tin nhắn gần đây giữa mọi người nếu có liên quan.`,
        '- Trả lời tự nhiên, súc tích (khoảng 2-5 câu, trừ khi cần giải thích chi tiết hoặc liệt kê rõ ràng).',
        '- Không mở đầu bằng tiền tố "VioraAI:". Không bịa thông tin không có trong đoạn chat.',
        '- Trả lời hoàn toàn bằng tiếng Việt tự nhiên, lịch sự và gần gũi.',
      ].join('\n');

  const messagesPayload = [{ role: 'system', content: systemPrompt }];

  if (Array.isArray(history) && history.length > 0) {
    for (const h of history.slice(-12)) {
      const content = (h.content || h.text || '').toString().trim();
      if (!content) continue;
      if (h.isAi) {
        messagesPayload.push({ role: 'assistant', content });
      } else {
        const who = (h.senderName && h.senderName.trim()) ? h.senderName.trim() : (isEn ? 'Member' : 'Thành viên');
        messagesPayload.push({ role: 'user', content: `${who}: ${content}` });
      }
    }
  }

  const finalQuery = (promptText && promptText.trim())
    ? `${cleanSpeaker} (@VioraAI): ${promptText.trim()}`
    : (isEn ? `${cleanSpeaker} tagged @VioraAI.` : `${cleanSpeaker} vừa nhắc @VioraAI.`);
  messagesPayload.push({ role: 'user', content: finalQuery });

  return await callGroq({
    messages: messagesPayload,
    maxTokens: 450,
    temperature: 0.65,
  });
}

module.exports = {
  isConfigured,
  summarizeMessages,
  chatWithVioraAI,
  explainTermInContext,
  translateText,
  replyAsThirdPartyParticipant,
};
