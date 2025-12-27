// classification.js
// This file contains the pure logic, separated from the server/database.

const CLASSIFICATION_RULES = {
    categories: {
        scheduling: ['meeting', 'schedule', 'call', 'appointment', 'deadline'],
        finance: ['payment', 'invoice', 'bill', 'budget', 'cost', 'expense'],
        technical: ['bug', 'fix', 'error', 'install', 'repair', 'maintain'],
        safety: ['safety', 'hazard', 'inspection', 'compliance', 'ppe']
    },
    priorities: {
        high: ['urgent', 'asap', 'immediately', 'today', 'critical', 'emergency'],
        medium: ['soon', 'this week', 'important']
    },
    actions: {
        scheduling: ["Block calendar", "Send invite", "Prepare agenda", "Set reminder"],
        finance: ["Check budget", "Get approval", "Generate invoice", "Update records"],
        technical: ["Diagnose issue", "Check resources", "Assign technician", "Document fix"],
        safety: ["Conduct inspection", "File report", "Notify supervisor", "Update checklist"],
        general: ["Review task", "Set deadline"]
    }
};

function classifyTask(title, description) {
    const text = `${title} ${description}`.toLowerCase();
    
    // 1. Determine Category
    let category = 'general';
    for (const [cat, keywords] of Object.entries(CLASSIFICATION_RULES.categories)) {
        if (keywords.some(k => text.includes(k))) {
            category = cat;
            break; 
        }
    }

    // 2. Determine Priority
    let priority = 'low';
    for (const [prio, keywords] of Object.entries(CLASSIFICATION_RULES.priorities)) {
        if (keywords.some(k => text.includes(k))) {
            priority = prio;
            break;
        }
    }

    // 3. Entity Extraction
    const entities = {};
    const dateMatch = text.match(/\d{4}-\d{2}-\d{2}/);
    if (dateMatch) entities.date = dateMatch[0];
    
    const personMatch = text.match(/(?:with|to|by)\s+([A-Z][a-z]+)/);
    if (personMatch) entities.person = personMatch[1];

    // 4. Suggested Actions
    const suggested_actions = CLASSIFICATION_RULES.actions[category] || CLASSIFICATION_RULES.actions.general;

    return { category, priority, extracted_entities: entities, suggested_actions };
}

module.exports = { classifyTask };