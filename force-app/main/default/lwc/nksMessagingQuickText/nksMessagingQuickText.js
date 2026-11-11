import { LightningElement, wire } from 'lwc';
import getQuicktexts from '@salesforce/apex/CRM_HenvendelseQuicktextController.getQuicktexts';

const QUICK_TEXT_TRIGGER_KEYS = ['Enter', ';', ','];

export default class NksMessagingQuickText extends LightningElement {
    quickTextMap = [];
    recentlyInserted = '';
    _boundEditors = new Map();
    _scanInterval;
    iteration = 0;

    connectedCallback() {
        this.bindEditors();
        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-interval
        this._scanInterval = window.setInterval(() => {
            this.bindEditors();
        }, 1000);
    }

    disconnectedCallback() {
        if (this._scanInterval) {
            window.clearInterval(this._scanInterval);
            this._scanInterval = null;
        }
        this._boundEditors.forEach((handler, editor) => {
            editor.removeEventListener('keyup', handler);
        });
        this._boundEditors.clear();
    }

    @wire(getQuicktexts, {})
    wiredQuicktexts({ error, data }) {
        if (error) {
            console.error('getQuicktexts error:', error);
            this.quickTextMap = [];
        } else if (data) {
            this.quickTextMap = data.map((row) => {
                const message = row.Message ?? '';
                const isCaseSensitive = Boolean(row.Case_sensitive__c);
                const abbreviation = row.nksAbbreviationKey__c ?? '';

                return {
                    abbreviation,
                    abbreviationUpper: abbreviation.toUpperCase(),
                    content: {
                        message,
                        isCaseSensitive
                    }
                };
            });
        }
    }

    bindEditors() {
        if (this.iteration > 20) {
            console.log('Max iterations reached');
            if (this._scanInterval) {
                window.clearInterval(this._scanInterval);
                this._scanInterval = null;
            }
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-document-query
        const conversationBodies = document.querySelectorAll('[data-target-selection-name="scrt_conversationBody"]');

        conversationBodies.forEach((conversationBody) => {
            const editor = conversationBody.querySelector('textarea');
            if (!editor || this._boundEditors.has(editor)) {
                return;
            }

            const handler = (event) => {
                if (QUICK_TEXT_TRIGGER_KEYS.includes(event.key)) {
                    this.insertquicktext(event, editor);
                }
            };
            this._boundEditors.set(editor, handler);
            editor.addEventListener('keyup', handler);
        });
        this.iteration++;
    }

    insertquicktext(event, editor) {
        if (
            event.isComposing ||
            event.ctrlKey ||
            event.altKey ||
            event.metaKey ||
            editor.selectionStart !== editor.selectionEnd
        ) {
            return;
        }

        if (!Array.isArray(this.quickTextMap) || this.quickTextMap.length === 0) {
            this.recentlyInserted = '';
            return;
        }

        const caretEnd = editor.selectionEnd;
        const trigger = event.key === 'Enter' ? '\n' : event.key;
        const beforeCaret = editor.value.substring(0, caretEnd);

        if (!beforeCaret.endsWith(trigger)) {
            this.recentlyInserted = '';
            return;
        }

        const lastWord = beforeCaret.slice(0, -trigger.length).match(/(?:^|\s)(\S+)$/)?.[1];
        const obj = this._getQmappedItem(lastWord);

        if (!obj) {
            this.recentlyInserted = '';
            return;
        }

        const quickText = obj.content?.message ?? '';
        const isCaseSensitive = Boolean(obj.content?.isCaseSensitive);
        const startIndex = caretEnd - lastWord.length - trigger.length;
        const lastChar = event.key === ';' ? '' : trigger;

        if (isCaseSensitive) {
            const words = quickText.split(' ');
            const first = lastWord.charAt(0);

            if (first && first === first.toLowerCase()) {
                words[0] = (words[0] || '').toLowerCase();
                const lowerCaseQuickText = words.join(' ');
                this._replaceWithQuickText(editor, lowerCaseQuickText + lastChar, startIndex, caretEnd);
                return;
            }

            if (first && first === first.toUpperCase()) {
                const upperCaseQuickText = (quickText.charAt(0) || '').toUpperCase() + quickText.slice(1);
                this._replaceWithQuickText(editor, upperCaseQuickText + lastChar, startIndex, caretEnd);
                return;
            }
        }

        this._replaceWithQuickText(editor, quickText + lastChar, startIndex, caretEnd);
    }

    _getQmappedItem(abbreviation) {
        if (!abbreviation || !Array.isArray(this.quickTextMap)) return null;

        const needleUpper = abbreviation.toUpperCase();
        const found = this.quickTextMap.find((item) => item.abbreviationUpper === needleUpper);
        if (found) return found;

        return this.quickTextMap.find((item) => item.abbreviation === abbreviation) ?? null;
    }

    _replaceWithQuickText(editor, replacement, start, end) {
        const safeStart = Math.max(0, start);
        const safeEnd = Math.max(safeStart, end);

        editor.setRangeText(replacement, safeStart, safeEnd);
        const caret = safeStart + replacement.length;
        editor.setSelectionRange(caret, caret);
        editor.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));

        this.recentlyInserted = replacement;
    }
}
