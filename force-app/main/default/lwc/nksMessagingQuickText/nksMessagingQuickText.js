import { LightningElement, wire } from 'lwc';
import getQuicktexts from '@salesforce/apex/CRM_HenvendelseQuicktextController.getQuicktexts';

const QUICK_TEXT_TRIGGER_KEYS = ['Enter', ' ', ','];

export default class NksMessagingQuickText extends LightningElement {
    quickTextMap = [];
    recentlyInserted = '';
    // eslint-disable-next-line compat/compat
    _boundEditors = new WeakSet();
    _scanInterval;

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
        // eslint-disable-next-line @lwc/lwc/no-document-query
        const conversationBodies = document.querySelectorAll('[data-target-selection-name="scrt_conversationBody"]');

        conversationBodies.forEach((conversationBody) => {
            const editor = conversationBody.querySelector('textarea');
            if (!editor || this._boundEditors.has(editor)) {
                return;
            }

            this._boundEditors.add(editor);

            editor.addEventListener('keyup', (event) => {
                if (QUICK_TEXT_TRIGGER_KEYS.includes(event.key)) {
                    this.insertquicktext(event, editor);
                }
            });
        });
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

        editor.setRangeText(replacement, safeStart, safeEnd, 'end');
        editor.dispatchEvent(new CustomEvent('input', { bubbles: true }));

        this.recentlyInserted = replacement;
    }
}
