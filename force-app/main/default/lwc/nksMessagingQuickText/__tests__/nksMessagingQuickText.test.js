import { createElement } from 'lwc';
import NksMessagingQuickText from 'c/nksMessagingQuickText';
import getQuicktexts from '@salesforce/apex/CRM_HenvendelseQuicktextController.getQuicktexts';

jest.mock(
    '@salesforce/apex/CRM_HenvendelseQuicktextController.getQuicktexts',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const QUICK_TEXTS = [
    {
        nksAbbreviationKey__c: 'AAP',
        Message: 'Arbeidsavklaringspenger',
        Case_sensitive__c: true
    },
    {
        nksAbbreviationKey__c: 'NAY',
        Message: 'NAV Arbeid og ytelser',
        Case_sensitive__c: false
    }
];

function createEditor() {
    const body = document.createElement('div');
    body.dataset.targetSelectionName = 'scrt_conversationBody';
    const editor = document.createElement('textarea');
    body.appendChild(editor);
    document.body.appendChild(body);
    return editor;
}

function keyUp(editor, text, key = ';', options = {}) {
    editor.value = text;
    editor.setSelectionRange(text.length, text.length);
    editor.dispatchEvent(new KeyboardEvent('keyup', { key, ...options }));
}

async function mount() {
    const component = createElement('c-nks-messaging-quick-text', {
        is: NksMessagingQuickText
    });
    document.body.appendChild(component);
    getQuicktexts.emit(QUICK_TEXTS);
    await Promise.resolve();
    return component;
}

describe('c-nks-messaging-quick-text', () => {
    beforeEach(() => {
        jest.useFakeTimers();
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllTimers();
        jest.useRealTimers();
        jest.restoreAllMocks();
    });

    it('consumes the semicolon and notifies the composer without adding a space', async () => {
        const editor = createEditor();
        await mount();
        const input = jest.fn();
        editor.addEventListener('input', input);

        keyUp(editor, 'AAP;');

        expect(editor.value).toBe('Arbeidsavklaringspenger');
        expect(editor.selectionStart).toBe(editor.value.length);
        expect(input).toHaveBeenCalledTimes(1);
        expect(input.mock.calls[0][0]).toMatchObject({
            type: 'input',
            bubbles: true,
            composed: true
        });
    });

    it.each([
        ['AAP ', ' '],
        ['unknown;', ';'],
        ['XAAP;', ';'],
        ['AAP;;', ';'],
        ['AAP ;', ';'],
        ['AAP', ';']
    ])('leaves %j unchanged on %j', async (text, key) => {
        const editor = createEditor();
        await mount();
        const input = jest.fn();
        editor.addEventListener('input', input);

        keyUp(editor, text, key);

        expect(editor.value).toBe(text);
        expect(input).not.toHaveBeenCalled();
    });

    it('preserves surrounding text, caret position and other conversation drafts', async () => {
        const editor = createEditor();
        const otherEditor = createEditor();
        otherEditor.value = 'Other draft';
        await mount();
        editor.value = 'Before\n\tAAP; after';
        const caret = editor.value.indexOf(';') + 1;
        editor.setSelectionRange(caret, caret);

        editor.dispatchEvent(new KeyboardEvent('keyup', { key: ';' }));

        expect(editor.value).toBe('Before\n\tArbeidsavklaringspenger after');
        expect(editor.selectionStart).toBe('Before\n\tArbeidsavklaringspenger'.length);
        expect(editor.selectionEnd).toBe(editor.selectionStart);
        expect(otherEditor.value).toBe('Other draft');
    });

    it.each([
        ['aap;', 'arbeidsavklaringspenger'],
        ['AaP;', 'Arbeidsavklaringspenger'],
        ['nay;', 'NAV Arbeid og ytelser']
    ])('preserves capitalization rules for %j', async (text, expected) => {
        const editor = createEditor();
        await mount();

        keyUp(editor, text);

        expect(editor.value).toBe(expected);
    });

    it.each([
        [',', 'AAP,', 'Arbeidsavklaringspenger,'],
        ['Enter', 'AAP\n', 'Arbeidsavklaringspenger\n']
    ])('preserves the existing %j trigger', async (key, text, expected) => {
        const editor = createEditor();
        await mount();

        keyUp(editor, text, key);

        expect(editor.value).toBe(expected);
    });

    it.each([{ isComposing: true }, { ctrlKey: true }, { altKey: true }, { metaKey: true }])(
        'does not expand during composition or modified shortcuts: %j',
        async (options) => {
            const editor = createEditor();
            await mount();

            keyUp(editor, 'AAP;', ';', options);

            expect(editor.value).toBe('AAP;');
        }
    );

    it('does not replace selected text', async () => {
        const editor = createEditor();
        await mount();
        editor.value = 'AAP;';
        editor.setSelectionRange(0, editor.value.length);

        editor.dispatchEvent(new KeyboardEvent('keyup', { key: ';' }));

        expect(editor.value).toBe('AAP;');
    });

    it('binds delayed and replacement editors during discovery', async () => {
        await mount();
        const oldEditor = createEditor();
        jest.advanceTimersByTime(1000);
        keyUp(oldEditor, 'AAP;');
        expect(oldEditor.value).toBe('Arbeidsavklaringspenger');
        oldEditor.parentElement.remove();
        const editor = createEditor();
        jest.advanceTimersByTime(1000);

        keyUp(editor, 'AAP;');

        expect(editor.value).toBe('Arbeidsavklaringspenger');
    });

    it('removes listeners and resumes binding on reconnect without duplicating them', async () => {
        const editor = createEditor();
        const component = await mount();
        document.body.removeChild(component);
        keyUp(editor, 'AAP;');
        expect(editor.value).toBe('AAP;');
        expect(jest.getTimerCount()).toBe(0);

        document.body.appendChild(component);
        jest.advanceTimersByTime(3000);
        const input = jest.fn();
        editor.addEventListener('input', input);
        keyUp(editor, 'AAP;');

        expect(editor.value).toBe('Arbeidsavklaringspenger');
        expect(input).toHaveBeenCalledTimes(1);
    });
});
