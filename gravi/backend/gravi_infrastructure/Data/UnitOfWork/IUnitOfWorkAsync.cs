using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork
{
    public interface IUnitOfWorkAsync
    {
        IDbConnection Connection { get; }
        IDbTransaction? Transaction { get; }

        Task BeginTransactionAsync();
        Task CommitAsync();
        Task RollBackAsync();
        Task DisposeAsync();
    }
}
