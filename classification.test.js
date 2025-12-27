const { classifyTask } = require('./classification');

describe('Task Classification Logic', () => {

    // Test 1: Category Detection
    test('should correctly classify finance tasks', () => {
        const title = "Pay the internet bill";
        const description = "Monthly invoice for office wifi";
        
        const result = classifyTask(title, description);
        
        expect(result.category).toBe('finance');
        expect(result.suggested_actions).toContain('Generate invoice');
    });

    // Test 2: Priority Detection
    test('should detect high priority for urgent keywords', () => {
        const title = "Fix critical bug immediately";
        const description = "Production server is down";
        
        const result = classifyTask(title, description);
        
        expect(result.priority).toBe('high');
        expect(result.category).toBe('technical');
    });

    // Test 3: Default Behavior
    test('should default to general category and low priority', () => {
        const title = "Buy coffee";
        const description = "For the office kitchen";
        
        const result = classifyTask(title, description);
        
        expect(result.category).toBe('general');
        expect(result.priority).toBe('low');
    });

    // Test 4: Entity Extraction
    test('should extract names and dates', () => {
        const title = "Meeting with Sarah";
        const description = "Scheduled for 2023-12-25";
        
        const result = classifyTask(title, description);
        
        expect(result.extracted_entities.person).toBe('Sarah');
        expect(result.extracted_entities.date).toBe('2023-12-25');
    });
});