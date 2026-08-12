import type { ReactNode } from 'react'
import type { SelectableClinicalListItem } from '../features/patientSummary/patientSummaryModel'

type SelectableClinicalSummarySectionProps = {
  title: string
  items: SelectableClinicalListItem[]
  emptyMessage?: string
  footer?: ReactNode
  onSelect: (item: SelectableClinicalListItem) => void
}

export function SelectableClinicalSummarySection({
  title,
  items,
  emptyMessage = 'None recorded',
  footer,
  onSelect,
}: SelectableClinicalSummarySectionProps) {
  const visibleItems = items.slice(0, 10)

  return (
    <section className="summary-card clinical-summary-card">
      <div className="clinical-summary-header">
        <h3>{title}</h3>
        <span className="clinical-summary-cap">Up to 10 items</span>
      </div>

      {visibleItems.length > 0 ? (
        <ul className="clinical-list">
          {visibleItems.map((item) => (
            <li key={`${title}-${item.id}`} className="clinical-list-selectable-item">
              <button
                type="button"
                className="clinical-select-button"
                onClick={() => onSelect(item)}
              >
                <div className="clinical-list-main">
                  <p className="clinical-item-title">{item.title}</p>
                  {item.secondaryText ? (
                    <p className="clinical-item-secondary">{item.secondaryText}</p>
                  ) : null}
                </div>

                <div className="clinical-item-meta">
                  {item.dateLabel && item.dateValue ? (
                    <>
                      <span className="clinical-item-date-label">
                        {item.dateLabel}
                      </span>
                      <span className="clinical-item-date-value">
                        {item.dateValue}
                      </span>
                    </>
                  ) : (
                    <span className="clinical-item-date-value">--</span>
                  )}
                </div>
              </button>
            </li>
          ))}
        </ul>
      ) : (
        <p className="empty-state">{emptyMessage}</p>
      )}

      {footer ? <div className="clinical-section-footer">{footer}</div> : null}
    </section>
  )
}
