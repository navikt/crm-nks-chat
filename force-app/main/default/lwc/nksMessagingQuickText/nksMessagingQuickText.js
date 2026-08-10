import { LightningElement, wire } from 'lwc';
import getQuicktexts from '@salesforce/apex/CRM_HenvendelseQuicktextController.getQuicktexts';

const QUICK_TEXT_TRIGGER_KEYS = ['Enter', ' ', ','];

export default class NksMessagingQuickText extends LightningElement {
    quickTextMap = [];
    recentlyInserted = '';
    _boundEditors = new Map();
    _observer = null;

    connectedCallback() {
        this._bindEditors();

        this._observer = new MutationObserver(() => {
            this._bindEditors();
            this._cleanupEditors();
        });

        this._observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    disconnectedCallback() {
        this._removeAllListeners();

        if (this._observer) {
            this._observer.disconnect();
            this._observer = null;
        }
    }

    @wire(getQuicktexts, {})
    wiredQuicktexts({ error, data }) {
        if (error) {
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

    _bindEditors() {
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

            editor.addEventListener('keyup', handler);
            this._boundEditors.set(editor, handler);
        });
    }

    _cleanupEditors() {
        for (const [editor, handler] of this._boundEditors.entries()) {
            if (!document.body.contains(editor)) {
                editor.removeEventListener('keyup', handler);
                this._boundEditors.delete(editor);
            }
        }
    }

    _removeAllListeners() {
        for (const [editor, handler] of this._boundEditors.entries()) {
            editor.removeEventListener('keyup', handler);
        }
        this._boundEditors.clear();
    }

    insertquicktext(event, editor) {
        if (!Array.isArray(this.quickTextMap) || this.quickTextMap.length === 0) {
            this.recentlyInserted = '';
            return;
        }

        const caretEnd = editor.selectionEnd;
        const lastItem = editor.value
            .substring(0, caretEnd)
            .replace(/(\r\n|\n|\r)/g, ' ')
            .trim()
            .split(' ')
            .pop();

        if (!lastItem) {
            this.recentlyInserted = '';
            return;
        }

        const lastWord = lastItem.replace(event.key, '');
        const obj = this._getQmappedItem(lastWord);

        if (!obj) {
            this.recentlyInserted = '';
            return;
        }

        const quickText = obj.content?.message ?? '';
        const isCaseSensitive = Boolean(obj.content?.isCaseSensitive);
        const startIndex = caretEnd - lastWord.length - 1;
        const lastChar = event.key === 'Enter' ? '\n' : event.key;

        if (isCaseSensitive) {
            const words = quickText.split(' ');
            const first = lastItem.charAt(0);

            if (first && first === first.toLowerCase()) {
                words[0] = (words[0] || '').toLowerCase();
                this._replaceWithQuickText(editor, words.join(' ') + lastChar, startIndex, caretEnd);
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

        editor.setRangeText(replacement, safeStart, safeEnd, 'end');
        // eslint-disable-next-line @lwc/lwc/prefer-custom-event
        editor.dispatchEvent(new Event('input', { bubbles: true }));
        this.recentlyInserted = replacement;
    }
}
