using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork
{
    public interface IUnitOfWorkAsync : IDisposable
    {
        DbConnection Connection { get; }
        DbTransaction? Transaction { get; }

        Task BeginTransactionAsync();
        Task CommitAsync();
        Task RollBackAsync();
        Task DisposeAsync();
    }
}
